require 'forwardable'
require 'sshkey'

require 'linecook-gem/builder/lxc'
require 'linecook-gem/builder/darwin_backend'
require 'linecook-gem/builder/linux_backend'
require 'linecook-gem/builder/build'

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
      increase_loop_devices
    end

    def ssh
      config = Linecook.config[:builder]
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

    def increase_loop_devices
      kparams = {}

      ssh.capture('cat /proc/cmdline').split(/\s+/).each do |param|
        k,v = param.split('=')
        kparams[k] = v
      end

      if loops = kparams['max_loop']
        current =  ssh.capture('ls -1 /dev | grep loop')
        last_loop = current.lines.length
        to_create = loops.to_i - last_loop

        to_create.times do |count|
          index = last_loop + count
          ssh.run("[ ! -e /dev/loop#{index} ] && sudo mknod -m660 /dev/loop#{index} b 7 #{index}")
          ssh.run("sudo chown root:disk /dev/loop#{index}")
        end
      end
    end

  end
end
