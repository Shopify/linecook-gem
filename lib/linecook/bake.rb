require 'socket'

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
        environment: chef_config[:environment] || 'master',
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

    # Technically race conditions are possible, but should be unlikely
    def get_free_port
      socket = Socket.new(:INET, :STREAM, 0)
      socket.bind(Addrinfo.tcp("127.0.0.1", 0))
      port = socket.local_address.ip_port
      socket.close
      port
    end

    def setup_chef_client_file
      client_file = Tempfile.new('chef-provisioner-client')
      client_file.write(OpenSSL::PKey::RSA.new(2048).to_s)
      client_file.close
      client_file.path
    end


    def setup
      config = Linecook::Config.load_config
      chef_port = get_free_port
      chef_client_file = setup_chef_client_file

      chef_config = config[:chef]
      chef_config.merge!(DEFAULT_CONFIG)
      chef_config.merge!({
        client_key: chef_client_file,
        chef_server_url: "http://0.0.0.0:#{chef_port}",
      })


      puts chef_config
      Chefdepartie.run(background: true, config: chef_config)
      ChefProvisioner::Chef.configure(endpoint: "http://#{Socket.gethostname}:#{chef_port}", key_path: chef_client_file, client: 'linecook')
      chef_config
    end


  end

end
