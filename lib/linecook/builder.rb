require 'sshkey'

require 'linecook/lxc'
# Make Builder a superclass
# With linux and OS X subclasses
#
# - list all LXC builds inside of the builder
# - upload images to the builder
# - store state
#  - PID, if builder is already
#   - IP
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

    def backend
      @backend ||= backend_for_platform
    end

    def info
      backend.info
    end

    def ip
      backend.ip
    end

    def start
      backend.start unless running?
      ssh.run('sudo stop cgmanager') # FIXME -only on linux, needed for os x?
      setup_bridge
      #pubkey = SSHKey.new(File.read(File.expand_path("~/.ssh/id_rsa"))).ssh_public_key # FIXME - be able to generate a one off
      #@ssh.run("mkdir -p /home/#{config[:username]}/.ssh")
      #@ssh.upload(pubkey, "/home/#{config[:username]}/.ssh/authorized_keys")
    end

    def ssh
      config = Linecook::Config.load_config[:builder]
      @ssh ||= SSH.new(ip, username: config[:username], password: config[:password])
    end

    def stop
      backend.stop
    end

    def running?
      backend.running?
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

  module LinuxBuilder
    extend self
    LXC_MIN_VERSION = '1.0.7'

    def backend
      check_lxc_version
      config = Linecook::Config.load_config[:builder]
      images = Linecook::Config.load_config[:images]
      Linecook::Lxc::Container.new(name: config[:name], home: config[:home], image: images[config[:image]])
    end

  private

    def check_lxc_version
      version = `lxc-info --version`
      fail "lxc too old (<#{LXC_MIN_VERSION}) or not present" unless Gem::Version.new(version) >= Gem::Version.new(LXC_MIN_VERSION)
    end
  end

  module OSXBuilder
    extend self
    def backend
      require 'xhyve'
    end
  end
end
