require 'net/http'
require 'open-uri'
require 'timeout'
require 'tmpdir'
require 'securerandom'

require 'linecook/util/ssh'
require 'linecook/util/executor'

require 'aws-sdk'

module Linecook
  # Installs a linecook image on a target device
  module Packager
    class EBS
      include Executor

      def initialize(hvm: true, size: 10, region: nil, copy_regions: [], account_ids: [])
        @hvm = hvm
        @size = size
        @region = region
        @copy_regions = copy_regions
        @account_ids = account_ids
      end

      def package(image, type: nil, ami: nil)
        @image = image
        @source = File.basename(@image)
        @name = "#{@source}-#{SecureRandom.hex(4)}"
        @type = type
        setup_image
        prepare
        execute("tar -C #{@mountpoint} -cpf - . | sudo tar -C #{@root} -xpf -")
        finalize
        snapshot
        cleanup
        create_ami if ami
      end

    private

      def prepare
        @mountpoint = Dir.mktmpdir
        execute("mkdir -p #{@mountpoint}")
        execute("mount #{@image} #{@mountpoint}")
        create_volume
        format_and_mount
      end

      def finalize
        execute("echo \"UUID=\\\"$(blkid -o value -s UUID #{@rootdev})\\\" /               ext4            defaults  1 2\" > /tmp/fstab")
        execute("mv /tmp/fstab #{@root}/etc/fstab")
        chroot_exec('apt-get update')
        chroot_exec('apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes --no-upgrade install grub-pc grub-legacy-ec2')
        chroot_exec('update-grub')
        execute("grub-install --root-directory=#{@root} $(echo #{@rootdev} | sed \"s/[0-9]*//g\")") if @hvm
      end

      def cleanup
        execute("umount #{@image}")
        execute("rm -f #{@image}")
        execute("rmdir #{@mountpoint}")
      end

      def chroot_exec(command)
        execute("mount -o bind /dev #{@root}/dev")
        execute("mount -o bind /sys #{@root}/sys")
        execute("mount -t proc none #{@root}/proc")
        execute("cp /etc/resolv.conf #{@root}/etc")
        execute("chroot #{@root} #{command}")
        execute("umount #{@root}/dev")
        execute("umount #{@root}/sys")
        execute("umount #{@root}/proc")
      end

      def partition
        execute("parted -s #{@rootdev} mklabel msdos")
        execute("parted -s #{@rootdev} mkpart primary ext2 0% 100%")
        @rootdev = "#{@rootdev}1"
      end

      def format_and_mount
        partition if @hvm
        execute("mkfs.ext4 #{@rootdev}")
        @root = Dir.mktmpdir
        execute("mkdir -p #{@root}")
        execute("mount #{@rootdev} #{@root}")
      end

      def instance_id
        @instance_id ||= metadata('instance-id')
      end

      def availability_zone
        @availability_zone ||= metadata('placement/availability-zone')
      end

      def client(region: nil)
        @client = nil if region
        @client ||= begin
          region ||= @region
          puts "Using AWS region #{region} for following request"
          credentials = Aws::Credentials.new(Linecook.config[:aws][:access_key], Linecook.config[:aws][:secret_key])
          Aws::EC2::Client.new(region: region, credentials: credentials)
        end
      end

      def create_volume
        resp = client.create_volume({
          size: @size,
          availability_zone: availability_zone, # required
          volume_type: "standard", # accepts standard, io1, gp2
        })

        @volume_id = resp.volume_id
        rootdev = free_device

        puts "Waiting for volume to become available"
        wait_for_state('available', 120) do
          client.describe_volumes(volume_ids: [@volume_id]).volumes.first.state
        end

        resp = client.attach_volume({
          volume_id: @volume_id,
          instance_id: instance_id,
          device: rootdev,
        })

        puts "Waiting for volume to attach"
        wait_for_state('attached', 120) do
          client.describe_volumes(volume_ids: [@volume_id]).volumes.first.attachments.first.state
        end
        @rootdev = "/dev/#{rootdev}"
      end

      def snapshot
        execute("umount #{@root}")
        puts 'Creating snapshot'
        resp = client.detach_volume(volume_id: @volume_id)
        wait_for_state('available', 120) do
          client.describe_volumes(volume_ids: [@volume_id]).volumes.first.state
        end
        resp = client.create_snapshot(volume_id: @volume_id, description: "Snapshot of #{@name}")
        @snapshot_id = resp.snapshot_id
        tag(@snapshot_id, Name: "Linecook snapshot for #{@source}", type: @type, image: @name, hvm: @hvm.to_s)
        client.delete_volume(volume_id: @volume_id)
      end

      def create_ami

        puts "Waiting for snapshot #{@snapshot_id} to be completed"
        wait_for_state('completed', 900) do
          client.describe_snapshots(snapshot_ids: [@snapshot_id]).snapshots.first.state
        end

        puts "Registering an AMI with for #{@name}"
        options = {
          name: @name,
          virtualization_type: @hvm ? 'hvm' : 'paravirtual',
          architecture: 'x86_64', # fixme
          root_device_name: '/dev/sda1', # fixme when does this need to be sda?
          block_device_mappings: [{
            device_name: '/dev/sda1',
            ebs: {
              snapshot_id: @snapshot_id,
              volume_size: @size,
              volume_type: @hvm ? 'gp2' : 'standard', # fixme: support iops?
              delete_on_termination: true,
            }
          }]
        }
        options.merge!({sriov_net_support: 'simple'}) if @hvm

        resp = client.register_image(**options)
        @ami_id = resp.image_id

        wait_for_state('available', 300) do
          client.describe_images(image_ids: [@ami_id]).images.first.state
        end

        amis = {
          @region => @ami_id
        }

        @copy_regions.each do |region|
          puts "Copying #{@ami_id} to #{region}"
          resp = client(region: region).copy_image({
            source_region: @region,
            source_image_id: @ami_id,
            name: @name,
            description: "Copy of #{@name}",
          })
          ami = resp.image_id
          puts "Waiting for #{ami} to become available in #{region}"
          wait_for_state('available', 1800) do
            client.describe_images(image_ids: [ami]).images.first.state
          end
          amis[region] = ami
        end

        unless @account_ids.empty?
          amis.each do |region, ami|
            puts "Updating account permissions for #{ami} in #{region}"
            client(region: region).modify_image_attribute({
              operation_type: 'add',
              attribute: 'launchPermission',
              image_id: ami,
              user_ids: @account_ids
            })
          end
        end

        amis.each do |region, ami|
          tag(ami, region: region, source: @source, name: @name, type: @type, hvm: @hvm.to_s)
        end
        amis
      end

      def free_device
        prefix = device_prefix
        ('f'..'zzz').to_a.each do |suffix|
          device = "#{prefix}#{suffix}"
          if free_device?(device)
            lock_device(device)
            return device
          end
        end
        return nil
      end

      def free_device?(device)
        test("[ ! -e /dev/#{device} ]") && test("[ ! -e /run/lock/linecook-#{device} ]")
      end

      def lock_device(device)
        execute("echo #{Process.pid} > /run/lock/linecook-#{device}")
      end

      def unlock_device(device)
        execute("rm /run/lock/linecook-#{device}")
      end

      def device_prefix
        prefixes = ['xvd', 'sd']
        capture('ls -1 /sys/block').lines.each do |dev|
          prefixes.each do |prefix|
            return prefix if dev =~ /^#{prefix}/
          end
        end
        return prefixes.first
      end

      def setup_image
        path = "/tmp/#{File.basename(@image)}"
        if instance_id
          return if File.exists?(@image)
          Linecook::Downloader.download(image_url, path, encrypted: true)
          @image = path
        else
          start_node
          @remote.run("wget '#{image_url}' -nv -O #{path}")
          @image = Linecook::Crypto.new(remote: @remote).decrypt_file(path)
        end
      end

      def image_url
        @url ||= Linecook::ImageManager.url(File.basename(@image), type: @type)
      end

      def start_node
        resp = client.run_instances(
          image_id: find_ami,
          min_count: 1,
          max_count: 1,
          instance_type: 'c4.large',
          instance_initiated_shutdown_behavior: 'terminate',
          security_groups: [security_group],
          key_name: key_pair
        )
        @instance_id = resp.instances.first.instance_id
        @availability_zone = resp.instances.first.placement.availability_zone

        puts 'Waiting for temporary instance to come online'
        wait_for_state('running', 300) do
          client.describe_instances(instance_ids: [@instance_id]).reservations.first.instances.first.state.name
        end
        tag(@instance_id, Name: 'linecook-temporary-installer-node')
        @remote = Linecook::SSH.new(instance_ip, username: 'ubuntu', keyfile: Linecook::SSH.private_key)
        @remote.upload("exec shutdown -h 60 'Delayed shutdown started'", '/tmp/delay-shutdown')
        execute('mv /tmp/delay-shutdown /etc/init/delay-shutdown.conf') # ubuntism is ok, since the temporary host can always be ubuntu
        execute('start delay-shutdown')
        # Install crypto deps
        execute('apt-get install -y --force-yes build-essential ruby ruby-dev')
        execute('gem install rbnacl rbnacl-libsodium')
      end

      def find_ami
        url = "http://uec-images.ubuntu.com/query/trusty/server/released.current.txt"
        type = @hvm ? 'hvm' : 'paravirtual'
        data = open(url).read.split("\n").map{|l| l.split}.detect do |ary|
          ary[4] == 'ebs' &&
            ary[5] == 'amd64' &&
            ary[6] == @region &&
            ary.last == type
        end
        data[7]
      end

      def instance_ip
        client.describe_instances(instance_ids: [@instance_id]).reservations.first.instances.first.public_ip_address
      end

      def security_group
        group_name = 'linecook-global-ssh'
        resp = client.describe_security_groups(filters: [{name: 'group-name', values: [group_name]}])
        if resp.security_groups.length < 1
          resp = client.create_security_group({
            group_name: group_name,
            description: "Allow global ssh for linecook temporary builder instances",
          })

          resp = client.authorize_security_group_ingress({
            group_name: group_name,
            ip_protocol: "tcp",
            from_port: 22,
            to_port: 22,
            cidr_ip: "0.0.0.0/0",
          })
        end
        group_name
      end

      def tag(id, **kwargs)
        puts "Will tag #{id} with #{kwargs}"
        resp = client(region: kwargs[:region]).create_tags(resources: [id], tags: kwargs.map{ |k,v| {key: k.to_s, value: v.to_s } })
      end

      def key_pair
        pubkey = Linecook::SSH.public_key
        resp = client.describe_key_pairs({
          filters: [ { name: 'fingerprint', values: [Linecook::SSH.sshv2_fingerprint(pubkey)] } ]
        })

        if resp.key_pairs.length >= 1
          return resp.key_pairs.first.key_name
        else
          keyname = "linecook-#{SecureRandom.uuid}"
          resp = client.import_key_pair({
            key_name: keyname,
            public_key_material: pubkey,
          })
          return keyname
        end
      end

      def metadata(key)
       (Timeout::timeout(1) { Net::HTTP.get(URI(File.join("http://169.254.169.254/latest/meta-data", key))) } rescue nil)
      end

      def wait_for_state(desired, timeout)
        attempts = 0
        state = nil
        while attempts < timeout && state != desired
          state = yield
          attempts += 1
          sleep(1)
        end
      end
    end
  end
end
