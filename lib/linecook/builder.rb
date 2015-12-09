require 'forwardable'
require 'sshkey'

require 'linecook/lxc'
require 'linecook/darwin_backend'
require 'linecook/linux_backend'
#
# Linux builder:
#  - just checks for a bridge interface
#  - download live image, if not already
#  - sets up lxc container using local lxc config
#  - copies base image into builder container

# OS X builder:
#  - download live ISO
#   - hdiutil
#  - create cache loopback image
#   - dd, based on config file.
#  - start xhyve using gem
#   - keep track of PID and IP
#  - copy base image into xhyve cache

# One linecook instance per build, but many linecook instances can share a single builder

module Linecook
  module Builder
    extend self
    extend Forwardable
    BUILD_HOME = '/u/lxc'

    def_instance_delegators :backend, :stop, :ip, :info, :running?

    def backend
      @backend ||= backend_for_platform
    end

    def start
      return if running?
      backend.start
      ssh.run('sudo stop cgmanager') # FIXME: -only on linux, needed for os x?
      setup_bridge
      # pubkey = SSHKey.new(File.read(File.expand_path("~/.ssh/id_rsa"))).ssh_public_key # FIXME - be able to generate a one off
      # @ssh.run("mkdir -p /home/#{config[:username]}/.ssh")
      # @ssh.upload(pubkey, "/home/#{config[:username]}/.ssh/authorized_keys")
    end

    def ssh
      config = Linecook::Config.load_config[:builder]
      @ssh ||= SSH.new(ip, username: config[:username], password: config[:password])
    end

    def builds
      ssh.test("[ -d #{BUILD_HOME} ]") ? ssh.capture("find  #{BUILD_HOME} -maxdepth 1 -mindepth 1 -type d -printf \"%f\n\"").delete(';').lines : []
    end

    def build_info
      info = {}
      builds.each do |build|
        info[build] = Linecook::Build.new(build, nil).info
      end
      info
    end

    private

    def setup_bridge
      interfaces = <<-eos
auto lo
iface lo inet loopback

auto lxcbr0
iface lxcbr0 inet dhcp
  bridge_ports eth0
  bridge_fd 0
  bridge_maxwait 0
eos
      ssh.upload(interfaces, '/tmp/interfaces')
      ssh.run('sudo mv /tmp/interfaces /etc/network/interfaces')
      ssh.run('sudo ifup lxcbr0')
    end

    def backend_for_platform
      case Config.platform
      when 'linux'
        LinuxBuilder.backend
      when 'darwin'
        OSXBuilder.backend
      else
        fail "Cannot find supported backend for #{Config.platform}"
      end
    end
  end
end
