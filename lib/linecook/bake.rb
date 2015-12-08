require 'securerandom'

require 'chef-provisioner'
require 'chefdepartie'

require 'linecook/ssh'

module Linecook

  module Baker
    extend self

    def bake
      chef_config = setup
      script = ChefProvisioner::Bootstrap.generate(
        node_name: chef_config[:node_name],
        chef_version: chef_config[:version] || nil,
        first_boot: {
          run_list: chef_config[:run_list],
        },
      )
      # Instantiate builder and build here
      #puts "Connecting to host..."
      #SSH::upload(script, '/tmp/chef_bootstrap')
      #SSH::run('sudo bash /tmp/chef_bootstrap')
    end

  private

    def setup
      ChefProvisioner::Config.setup(client: 'linecook')
      config = Linecook::Config.load_config

      chef_config = config[:chef]
      chef_config.merge!({
        node_name: "linecook-#{SecureRandom.uuid}",
        chef_server_url: "http://0.0.0.0:#{ChefProvisioner::Config.server.split(':')[-1]}",
      })

      Chefdepartie.run(background: true, config: chef_config, cache: '/tmp/linecook-cache')
      chef_config
    end
  end
end
