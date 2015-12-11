require 'forwardable'
require 'sshkey'

require 'linecook/lxc'
require 'linecook/darwin_backend'
require 'linecook/linux_backend'

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
