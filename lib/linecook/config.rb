require 'yaml'

module Linecook
  module Config
    extend self
    CONFIG_PATH = File.join(Dir.pwd, 'linecook.yml').freeze #File.expand_path('../../../config/config.yml', __FILE__)
    def load_config
      @config ||= begin
        config = YAML.load(File.read(CONFIG_PATH)).deep_symbolize_keys
        fail "Cookbook path not provided or doesn't exist" unless (config[:chef][:cookbook_path] && Dir.exists?(config[:chef][:cookbook_path]))
        fail "Databag secret not provided or doesn't exist" unless (config[:chef][:encrypted_data_bag_secret] && File.exists?(config[:chef][:encrypted_data_bag_secret]))
        config
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
  end
end
