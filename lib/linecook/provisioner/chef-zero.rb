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
        },
        audit: Linecook.config[:provisioner][:chefzero][:audit]
      )

      puts "Establishing connection to build..."
      build.start
      build.ssh.forward(chef_port)
      build.ssh.upload(script, '/tmp/chef_bootstrap')
      build.ssh.run('[ -f /var/chef/cache/chef-client-running.pid ] && sudo rm -f /var/chef/cache/chef-client-running.pid || true')
      build.ssh.run("sudo hostname #{chef_config[:node_name]}")
      build.ssh.run('sudo bash /tmp/chef_bootstrap')
      build.ssh.run('sudo rm -rf /etc/chef')
      build.ssh.stop_forwarding
      Chefdepartie.stop
      FileUtils.rm_rf(Cache.path)
    end

    def chef_port
      ChefProvisioner::Config.server.split(':')[-1].to_i
    end

    private

    def setup
      ChefProvisioner::Config.setup(client: 'linecook', listen: 'localhost')
      config = Linecook.config

      chef_config = config[:chef]
      chef_config.merge!(node_name: "linecook-#{SecureRandom.hex(4)}",
                         chef_server_url: ChefProvisioner::Config.server)
      Chefdepartie.run(background: true, config: chef_config, cache: Cache.path)
      chef_config
    end

    # Required in order to have multiple builds run on different refs
    module Cache
      CACHE_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'chefcache').freeze
      PIDFILE = File.join(CACHE_PATH, 'pid')
      STAMPFILE = File.join(CACHE_PATH, 'stamp')
      STALE_THRESHOLD = 86400 # one day in seconds
      WAIT_TIMEOUT = 60 # time to wait for port to become available again

      extend self

      def path
        @cache_path ||= begin
          FileUtils.mkdir_p(CACHE_PATH)
          cache_path = Dir.mktmpdir('linecook-chef-cache')
          build
          copy(cache_path)
          wait_for_close
          cache_path
        end
      end

    private

      def wait_for_close
        attempts = 0
        while attempts < WAIT_TIMEOUT
          begin
            Timeout::timeout(1) do
              begin
                s = TCPSocket.new('127.0.0.1', Linecook::Chef.chef_port)
                s.close
                return true
              rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                return false
              end
            end
          rescue Timeout::Error
            puts "Port #{Linecook::Chef.chef_port} is still in use"
            sleep(1)
          end
          attempts += 0
        end
      end

      def copy(cache_path)
        FileUtils.copy_entry(CACHE_PATH, cache_path, preserve: true)
      end

      def build
        if stale
          puts 'Regenerating cookbook cache'
          begin
            Chefdepartie.run(background: true, config: Linecook.config[:chef], cache: CACHE_PATH)
          rescue
            puts 'Cache tainted, rebuilding completely'
            FileUtils.rm_rf(CACHE_PATH)
            Chefdepartie.run(background: true, config: Linecook.config[:chef], cache: CACHE_PATH)
          ensure
            Chefdepartie.stop
          end
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
