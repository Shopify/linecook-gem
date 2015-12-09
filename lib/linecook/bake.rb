require 'securerandom'

require 'chef-provisioner'
require 'chefdepartie'

require 'linecook/build'

module Linecook
  module Baker
    extend self

    def bake
      chef_config = setup
      script = ChefProvisioner::Bootstrap.generate(
        node_name: chef_config[:node_name],
        chef_version: chef_config[:version] || nil,
        first_boot: {
          run_list: chef_config[:run_list]
        }
      )

      puts "Establishing connection to build..."
      build = Linecook::Build.new('test', 'ubuntu-base.squashfs')
      build.start
      build.ssh.forward(chef_port)
      build.ssh.upload(script, '/tmp/chef_bootstrap')
      build.ssh.run('sudo bash /tmp/chef_bootstrap')
      build.ssh.stop_forwarding
    end

    private

    def setup
      ChefProvisioner::Config.setup(client: 'linecook', listen: 'localhost')
      config = Linecook::Config.load_config

      chef_config = config[:chef]
      chef_config.merge!(node_name: "linecook-#{SecureRandom.uuid}",
                         chef_server_url: ChefProvisioner::Config.server)
      # FIXME: sort out cache copying here for concurrent builds of different refs
      Chefdepartie.run(background: true, config: chef_config, cache: '/tmp/linecook-cache')
      chef_config
    end

    def chef_port
      ChefProvisioner::Config.server.split(':')[-1].to_i
    end
  end
end
