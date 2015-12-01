require 'chef-provisioner'
require 'chefdepartie'

require 'linecook/ssh'

module Linecook

  module Baker
    extend self
    DEFAULT_CONFIG = {
      node_name: 'linecook-build',
    }

    def bake
      chef_config = setup
      script = ChefProvisioner::Bootstrap.generate(
        node_name: chef_config[:node_name],
        chef_version: chef_config[:version] || nil,
        first_boot: {
          run_list: chef_config[:run_list],
        },
      )
      puts "Connecting to host..."
      SSH::upload(script, '/tmp/chef_bootstrap')
      SSH::run('sudo bash /tmp/chef_bootstrap')
    end

  private

    def setup
      ChefProvisioner::Config.setup(client: 'linecook')
      config = Linecook::Config.load_config

      chef_config = config[:chef]
      chef_config.merge!(DEFAULT_CONFIG)
      chef_config.merge!({
        client_key: ChefProvisioner::Config.client_key,
        chef_server_url: ChefProvisioner::Config.server,
      })

      Chefdepartie.run(background: true, config: chef_config)
      chef_config
    end
  end
end
