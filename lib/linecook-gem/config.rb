require 'yaml'
require 'json'

module Linecook
  def self.config
    config = Config.config
    config
  end


  module Config
    extend self

    CONFIG_PATH = File.join(Dir.pwd, 'linecook.yml').freeze
    SECRETS_PATH = File.join(Dir.pwd, 'secrets.ejson').freeze
    LINECOOK_HOME = File.expand_path('~/.linecook').freeze
    DEFAULT_CONFIG_PATH = File.join(LINECOOK_HOME, 'config.yml').freeze

    def config
      @config ||= begin
        config_path = ENV['LINECOOK_CONFIG_PATH'] || CONFIG_PATH
        config = {}
        config ||= YAML.load(File.read(DEFAULT_CONFIG_PATH)) if File.exist?(DEFAULT_CONFIG_PATH)
        config.deep_merge!(YAML.load(File.read(config_path))) if File.exist?(config_path)
        (config || {}).deep_symbolize_keys!
        config.deep_merge!(secrets)
      end
    end

  private
    def secrets
      @secrets ||= begin
        secrets_path = ENV['LINECOOK_SECRETS_PATH'] || SECRETS_PATH
        if File.exists?(secrets_path)
          ejson_path = File.join(Gem::Specification.find_by_name('ejson').gem_dir, 'build', 'linux-amd64', 'ejson' )
          command = "#{ejson_path} decrypt #{secrets_path}"
          secrets = JSON.load(`sudo #{command}`)
          secrets.deep_symbolize_keys
        else
          {}
        end
      end
    end
  end
end
