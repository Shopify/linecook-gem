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
# FIXME: How to deal with concurrent builds on different branches / revisions?

module Linecook
  module Builder
    extend self
    extend Forwardable
    BUILD_HOME = '/u/lxc'

    attr_reader :pemfile
    def_instance_delegators :backend, :stop, :ip, :info, :running?

    def backend
      @backend ||= backend_for_platform
    end

    def start
      return if running?
      backend.start
      setup_ssh
    end

    def ssh
      config = Linecook::Config.load_config[:builder]
      @ssh ||= begin
        userkey = File.expand_path("~/.ssh/id_rsa")
        dedicated_key = File.join(Linecook::Config::LINECOOK_HOME, 'linecook_ssh.pem')
        unless File.exists?(dedicated_key)
          File.write(dedicated_key, SSHKey.generate.private_key)
          FileUtils.chmod(0600, dedicated_key)
        end
        @pemfile = File.exists?(userkey) ? userkey : dedicated_key
        puts @pemfile
        SSH.new(ip, username: config[:username], password: config[:password], keyfile: @pemfile)
      end
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

    def setup_ssh
      ssh
      pubkey = SSHKey.new(File.read(@pemfile)).ssh_public_key
      config = Linecook::Config.load_config[:builder]
      ssh.run("mkdir -p /home/#{config[:username]}/.ssh")
      ssh.upload(pubkey, "/home/#{config[:username]}/.ssh/authorized_keys")
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
