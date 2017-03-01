require 'json'
require 'mkmf'
require 'fileutils'
require 'open-uri'
require 'tempfile'
require 'tmpdir'
require 'pty'

require 'linecook-gem/image'
require 'linecook-gem/util/common'
require 'linecook-gem/packager/route53'
require 'linecook-gem/packager/packer'

module Linecook
  class AmiPacker < Packer

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
      'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure resolvconf' # re-linkify resolvconf
    ]

    def initialize(config)
      super(config)
      @hvm = config[:hvm] || true
      @root_size = config[:root_size] || 10
      @region = config[:region] || 'us-east-1'
      @copy_regions = config[:copy_regions] || []
      @accounts = config[:account_ids] || []
      @write_txt = Linecook.config[:packager] && Linecook.config[:packager][:ami] && Linecook.config[:packager][:ami][:update_txt]
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

    def extract_artifacts_from_output(output)
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
