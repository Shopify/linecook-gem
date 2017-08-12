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
require 'linecook-gem/util/common'
require 'linecook-gem/packager/route53'

module Linecook
  class AmiPacker

    include Downloader
    include Locking

    SOURCE_URL = 'https://releases.hashicorp.com/packer/'
    PACKER_VERSION = '0.12.0'
    PACKER_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'bin', 'packer')

    PRE_MOUNT_COMMANDS = [
      'parted -s {{.Device}} mklabel msdos',
      'parted -s {{.Device}} mkpart primary ext2 0% 100%',
      'mkfs.ext4 {{.Device}}1',
      'tune2fs -L cloudimg-rootfs {{.Device}}1',
    ]

    POST_MOUNT_COMMANDS = [
      'tar -C {{.MountPath}} -xpf {{ user `source_image_path` }}',
      'cp /etc/resolv.conf {{.MountPath}}/etc',
      'echo "LABEL=cloudimg-rootfs   /        ext4   defaults,discard        0 0" > {{.MountPath}}/etc/fstab',
      'grub-install --root-directory={{.MountPath}} {{.Device}}',
      'rm -rf {{.MountPath}}/etc/network',
      'cp -r /etc/network {{.MountPath}}/etc/',
    ]

    ROOT_DEVICE_MAP = {
      device_name: 'xvda',
      delete_on_termination: true
    }

    BUILDER_CONFIG = {
      type: 'amazon-chroot',
      access_key: '{{ user `aws_access_key` }}',
      secret_key: '{{ user `aws_secret_key` }}',
      ami_name: 'packer-image.{{ user `image_name` }} {{timestamp}}',
      from_scratch: true,
      root_device_name: ROOT_DEVICE_MAP[:device_name],
      ami_block_device_mappings: [ ROOT_DEVICE_MAP ],
      pre_mount_commands: PRE_MOUNT_COMMANDS,
      post_mount_commands: POST_MOUNT_COMMANDS,
    }.freeze

    CHROOT_COMMANDS = [
      'apt-get update',
      'DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes --no-upgrade install grub-pc grub-legacy-ec2',
      'update-grub',
      'rm -f /etc/init/fake-container-events.conf', # HACK
      'mkdir -p /run/resolvconf/interface',
      'echo "resolvconf resolvconf/linkify-resolvconf   boolean true" | debconf-set-selections', # write debconf
      'dpkg-reconfigure -f noninteractive resolvconf', # re-linkify resolvconf
      'truncate --size 0 /etc/resolv.conf', # clear build resolvconf config
      'truncate --size 0 /etc/resolvconf/resolv.conf.d/original' # clear build resolvconf config
    ]

    def initialize(config)
      system("#{packer_path} --version")
      @hvm = config[:hvm] || true
      @root_size = config[:root_size] || 10
      @region = config[:region] || 'us-east-1'
      @copy_regions = config[:copy_regions] || []
      @accounts = config[:account_ids] || []
      @write_txt = Linecook.config[:packager] && Linecook.config[:packager][:ami] && Linecook.config[:packager][:ami][:update_txt]
    end

    def package(image, directory)
      @image = image
      kitchen_config = load_config(directory).send(:data).instance_variable_get(:@data)
      image_config = kitchen_config[:suites].find{ |x| x[:name] == image.name }
      if image_config && image_config[:packager]
        packager = image_config[:packager] || {}
      end
      conf_file = Tempfile.new("#{@image.id}-packer.json")
      config = generate_config(packager)
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

    def generate_config(packager)
      packager ||= {}
      config = {
        variables: {
          aws_access_key: Linecook.config[:aws][:access_key],
          aws_secret_key: Linecook.config[:aws][:secret_key],
          image_name: "linecook-#{@image.id}",
          source_image_path: @image.path
        },
        builders: [
          BUILDER_CONFIG.merge(
            ami_users: @accounts,
            ami_regions: @copy_regions,
            ami_virtualization_type: virt_type,
            root_volume_size: @root_size
          ).deep_merge(packager[:builder] || {})
        ],
        provisioners: build_provisioner(CHROOT_COMMANDS)
      }

      unless config[:builders].first[:ami_block_device_mappings].find { |x| x[:device_name] == ROOT_DEVICE_MAP[:device_name] }
        config[:builders].first[:ami_block_device_mappings].prepend ROOT_DEVICE_MAP
      end
      JSON.pretty_generate(config)
    end

    def build_provisioner(chroot_commands)
      provisioner = [
        {
          type: 'shell',
          inline: chroot_commands
        }
      ]
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

      FileUtils.rm_f(Dir[File.join(File.dirname(PACKER_PATH), "*")])
      path = File.join(File.dirname(PACKER_PATH), 'packer.zip')
      url = File.join(SOURCE_URL, PACKER_VERSION, "packer_#{PACKER_VERSION}_linux_#{arch}.zip")
      download(url, path)
      unzip(path)
      PACKER_PATH
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

  end
end
