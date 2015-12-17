require 'yaml'
require 'json'
require 'fileutils'

require 'xhyve'

module Linecook
  module Config
    extend self
    attr_reader :config

    CONFIG_PATH = File.join(Dir.pwd, 'linecook.yml').freeze # File.expand_path('../../../config/config.yml', __FILE__)
    LINECOOK_HOME = File.expand_path('~/.linecook').freeze
    DEFAULT_CONFIG_PATH = File.join(LINECOOK_HOME, 'config.yml').freeze
    DEFAULT_CONFIG = {
      builder: {
        image: :live_image,
        name: 'builder',
        home: '/u/lxc',
        username: 'ubuntu',
        password: 'ubuntu'
      },
      provisioner: {
        default_provider: :chefzero,
        default_image: :base_image,
      },
      image: {
        provider: {
          public: :github,
          private: :s3,
        },
        images: {
          live_iso: {
            name: 'livesys.iso',
            profile: :public,
          },
          live_image: {
            name: 'livesys.squashfs',
            profile: :public,
          },
          base_image: {
            name: 'ubuntu-base.squashfs',
            profile: :public,
          }
        }
      },
      packager: {
        provider: :ebs,
        ebs: {
          hvm: true,
          size: 10,
          region: 'us-east-1'
        }
      },
      roles: {
      }
    }

    def secrets
      @secrets ||= begin
        if File.exists?('secrets.ejson')
          JSON.load(`ejson decrypt secrets.ejson`)
        else
          {}
        end
      end
    end

    def setup
      FileUtils.mkdir_p(LINECOOK_HOME)
      File.write(DEFAULT_CONFIG_PATH, YAML.dump(DEFAULT_CONFIG)) unless File.exist?(DEFAULT_CONFIG_PATH)
      check_perms if platform == 'darwin'
    end

    def check_perms
      fix_perms if (File.stat(Xhyve::BINARY_PATH).uid != 0 || !File.stat(Xhyve::BINARY_PATH).setuid?)
    end

    def fix_perms
      puts "Xhyve requires root until https://github.com/mist64/xhyve/issues/60 is resolved\nPlease enter your sudo password to setuid on the xhyve binary"
      system("sudo chown root #{Xhyve::BINARY_PATH}")
      system("sudo chmod +s #{Xhyve::BINARY_PATH}")
    end

    def load_config
      @config ||= begin
        config = YAML.load(File.read(DEFAULT_CONFIG_PATH)) if File.exist?(DEFAULT_CONFIG_PATH)
        config.merge!(YAML.load(File.read(CONFIG_PATH))) if File.exist?(CONFIG_PATH)
        # fail "Cookbook path not provided or doesn't exist" unless (config[:chef][:cookbook_path] && Dir.exists?(config[:chef][:cookbook_path]))
        # fail "Databag secret not provided or doesn't exist" unless (config[:chef][:encrypted_data_bag_secret] && File.exists?(config[:chef][:encrypted_data_bag_secret]))
        (config || {}).deep_symbolize_keys
      end
    end

    def platform
      case RbConfig::CONFIG['host_os'].downcase
      when /linux/
        'linux'
      when /darwin/
        'darwin'
      else
        fail 'Linux and OS X are the only supported systems'
      end
    end

    setup
  end
end
