require 'json'
require 'mkmf'
require 'fileutils'
require 'open-uri'
require 'tempfile'
require 'tmpdir'
require 'pty'

require 'linecook-gem/image'
require 'linecook-gem/util/downloader'
require 'linecook-gem/util/locking'
require 'linecook-gem/packager/route53'

module Linecook
  class AmiPacker

    include Downloader
    include Locking

    SOURCE_URL = 'https://releases.hashicorp.com/packer/'
    PACKER_VERSION = '0.12.0'
    PACKER_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'bin', 'packer')

    BUILDER_CONFIG = {
      type: 'amazon-chroot',
      access_key: '{{ user `aws_access_key` }}',
      secret_key: '{{ user `aws_secret_key` }}',
      source_ami: "{{user `source_ami`}}",
      ami_name: 'packer-image.{{ user `image_name` }} {{timestamp}}',
      device_path: '/dev/{{ user `ebs_device` }}'
    }.freeze

    PROVISIONER_COMMANDS = [
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/proc/sys/fs/binfmt_misc',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/proc',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/sys',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/dev/pts',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/dev',
      'mv /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc/network /tmp/{{ user `ebs_device`}}-network',
      'umount /dev/{{ user `ebs_device` }}1',
      'mkfs.ext4 /dev/{{ user `ebs_device` }}1',
      'tune2fs -L cloudimg-rootfs /dev/{{ user `ebs_device` }}1',
      'mkdir -p /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}',
      'mount /dev/{{ user `ebs_device` }}1 /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}',
      'tar -C /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }} -xpf {{ user `source_image_path` }}',
      'cp /etc/resolv.conf /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc',
      'echo "LABEL=cloudimg-rootfs   /        ext4   defaults,discard        0 0" > /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc/fstab',
      'mount -t proc none /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/proc',
      'mount -o bind /sys /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/sys',
      'mount -o bind /dev /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/dev',
      # Sadly we need to install grub inside the image, and this implementation is Ubunut specific. This can be patched eventually when needed
      'chroot /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }} apt-get update',
      'chroot /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }} apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes --no-upgrade install grub-pc grub-legacy-ec2',
      'chroot /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }} update-grub',
      'grub-install --root-directory=/mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }} /dev/{{ user `ebs_device` }}',
      'rm -rf /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc/network',
      'mv /tmp/{{ user `ebs_device`}}-network /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc/network',
      'rm -f /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/etc/init/fake-container-events.conf', # HACK
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/proc',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/sys',
      'umount /mnt/packer-amazon-chroot-volumes/{{ user `ebs_device` }}/dev'
    ]

    def initialize(config)
      system("#{packer_path} --version")
      @hvm = config[:hvm] || true
      @root_size = config[:root_size] || 10
      @region = config[:region] || 'us-east-1'
      @copy_regions = config[:copy_regions] || []
      @accounts = config[:account_ids] || []
      @source_ami = config[:source_ami] || find_ami
      @write_txt = Linecook.config[:packager] && Linecook.config[:packager][:ami] && Linecook.config[:packager][:ami][:update_txt]
    end

    def package(image)
      @image = image
      conf_file = Tempfile.new("#{@image.id}-packer.json")
      config = generate_config
      conf_file.write(config)
      conf_file.close
      output = []
      PTY.spawn("sudo #{PACKER_PATH} build -machine-readable #{conf_file.path}") do |stdout, _, _|
        begin
          stdout.each do |line|
            output << line if line =~ /artifact/
            tokens = line.split(',')
            if tokens.length > 4
              out = tokens[4].gsub('%!(PACKER_COMMA)', ',')
              time = DateTime.strptime(tokens[0], '%s').strftime('%c')
              puts "#{time} | #{out}"
            else
              puts "unexpected output format"
              puts tokens
            end
          end
        rescue Errno::EIO
          puts "Packer finshed executing"
        end
      end
      extract_amis_from_output(output)
    ensure
      conf_file.close
      conf_file.unlink
    end

  private

    # TO DO:
    # support for multiple accounts, multiple regions
    # code to extract ami name(s) from output
    #    amis = `grep "amazon-ebs,artifact,0,id" packer.log`.chomp.split(',')[5].split('%!(PACKER_COMMA)')
    # route53 TXT record integration

    def generate_config
      config = {
        variables: {
          aws_access_key: Linecook.config[:aws][:access_key],
          aws_secret_key: Linecook.config[:aws][:secret_key],
          ebs_device: free_device,
          source_ami: @source_ami,
          image_name: "linecook-#{@image.id}",
          source_image_path: @image.path
        },
        builders: [
          BUILDER_CONFIG.merge(
            ami_users: @accounts,
            ami_regions: @copy_regions,
            ami_virtualization_type: virt_type,
            root_volume_size: @root_size
          )
        ],
        provisioners: build_provisioner(PROVISIONER_COMMANDS)
      }
      JSON.pretty_generate(config)
    end

    def build_provisioner(commands)
      provisioner = []
      commands.each do |cmd|
        provisioner << {
          type: 'shell-local',
          command: cmd
        }
      end
      provisioner
    end

    def packer_path
      @path ||= begin
        found = File.exists?(PACKER_PATH) ? PACKER_PATH : find_executable('packer')
        path = if found
          version = `#{found} --version`
          Gem::Version.new(version) >= Gem::Version.new(PACKER_VERSION) ? found : nil
        end
        path ||= get_packer
      end
    end

    def get_packer
      puts "packer too old (<#{PACKER_VERSION}) or not present, getting latest packer"
      arch = 1.size == 8 ? 'amd64' : '386'
      path = File.join(File.dirname(PACKER_PATH), 'packer.zip')
      url = File.join(SOURCE_URL, PACKER_VERSION, "packer_#{PACKER_VERSION}_linux_#{arch}.zip")
      download(url, path)
      unzip(path)
      PACKER_PATH
    end

    def free_device
      lock('device_scan')
      free = nil
      prefix = device_prefix
      ('f'..'zzz').to_a.each do |suffix|
        device = "#{prefix}#{suffix}"
        if free_device?(device)
          lock(device)
          at_exit do
            clear_lock(device)
          end
          free = device
          break
        end
      end
      unlock('device_scan')
      return free
    end

    def free_device?(device)
      !File.exists?("/dev/#{device}") && !File.exists?(lock_path(device))
    end

    def device_prefix
      prefixes = ['xvd']
      `sudo ls -1 /sys/block`.lines.each do |dev| # FIXME
        prefixes.each do |prefix|
          return prefix if dev =~ /^#{prefix}/
        end
      end
      return prefixes.first
    end

    def extract_amis_from_output(output)
      amis = output.grep(/amazon-chroot,artifact,0,id/).first.chomp.split(',')[5].split('%!(PACKER_COMMA)')
      amis.each do |info_str|
        ami_info = info_str.split(':')
        ami_region = ami_info[0]
        ami_id = ami_info[1]
        puts "Built #{ami_id} for #{ami_region}"
        Linecook::Route53.upsert_record(@image.name, ami_id, ami_region) if @write_txt
      end
    end

    def virt_type
      @hvm ? 'hvm' : 'paravirtual'
    end

    def find_ami
      url = "http://uec-images.ubuntu.com/query/trusty/server/released.current.txt"
      data = open(url).read.split("\n").map{|l| l.split}.detect do |ary|
        ary[4] == 'ebs' &&
          ary[5] == 'amd64' &&
          ary[6] == @region &&
          ary.last == virt_type
      end
      data[7]
    end
  end
end
