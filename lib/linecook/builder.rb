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
      @ssh ||= SSH.new(ip, username: config[:username], password: config[:password], keyfile: Linecook::SSH.private_key)
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
