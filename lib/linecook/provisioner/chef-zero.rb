require 'tmpdir'
require 'fileutils'

require 'chef-provisioner'
require 'chefdepartie'

module Linecook
  module Chef
    extend self

    def provision(build, role)
      chef_config = setup
      role_config = Linecook.config[:roles][role.to_sym]
      script = ChefProvisioner::Bootstrap.generate(
        node_name: chef_config[:node_name],
        chef_version: chef_config[:version] || nil,
        first_boot: {
          run_list: role_config[:run_list]
        }
      )

      puts "Establishing connection to build..."
      build.start
      build.ssh.forward(chef_port)
      build.ssh.upload(script, '/tmp/chef_bootstrap')
      build.ssh.run('sudo bash /tmp/chef_bootstrap')
      build.ssh.run('sudo rm -rf /etc/chef')
      build.ssh.stop_forwarding
    end

    private

    def setup
      ChefProvisioner::Config.setup(client: 'linecook', listen: 'localhost')
      config = Linecook.config

      chef_config = config[:chef]
      chef_config.merge!(node_name: "linecook-#{SecureRandom.uuid}",
                         chef_server_url: ChefProvisioner::Config.server)
      # FIXME: sort out cache copying here for concurrent builds of different refs
      Chefdepartie.run(background: true, config: chef_config, cache: Cache.path)
      chef_config
    end

    def chef_port
      ChefProvisioner::Config.server.split(':')[-1].to_i
    end

    # Required in order to have multiple builds run on different refs
    module Cache
      CACHE_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'chefcache').freeze
      PIDFILE = File.join(CACHE_PATH, 'pid')
      STAMPFILE = File.join(CACHE_PATH, 'stamp')
      STALE_THRESHOLD = 86400 # one day in seconds

      extend self

      def path
        FileUtils.mkdir_p(CACHE_PATH)
        cache_path = Dir.mktmpdir
        build
        copy(cache_path)
        cache_path
      end

    private

      def copy(cache_path)
        FileUtils.copy_entry(CACHE_PATH, cache_path, preserve: true)
      end

      def build
        if stale
          puts 'Regenerating cookbook cache'
          Chefdepartie.run(background: true, config: Linecook.config[:chef], cache: CACHE_PATH)
          Chefdepartie.stop
          write_stamp
          unlock
        end
      end

      def stale
        return false if locked?
        lock
        old?
      end

      def locked?
        File.exists?(PIDFILE) && (true if Process.kill(0, File.read(PIDFILE)) rescue false)
      end

      def lock
        File.write(PIDFILE, Process.pid)
      end

      def unlock
        FileUtils.rm_f(PIDFILE)
      end

      def old?
        return true unless File.exists?(STAMPFILE)
        (Time.now.to_i - File.read(STAMPFILE).to_i) > STALE_THRESHOLD
      end

      def write_stamp
        File.write(STAMPFILE, Time.now.to_i)
      end
    end
  end
end
