require 'json'

require 'kitchen/configurable'

# FIXME - overhaul linecook config
# be able to read kitchen configs

module Linecook
  class Secrets

    SECRETS_PATH = File.join(Dir.pwd, 'secrets.ejson').freeze

    include Configurable

    def initialize(config = {})
      init_config(config)
    end

#    CONFIG_PATH = File.join(Dir.pwd, 'linecook.yml').freeze # File.expand_path('../../../config/config.yml', __FILE__)
#    LINECOOK_HOME = File.expand_path('~/.linecook').freeze
#    DEFAULT_CONFIG = {
#      packager: {
#        provider: :ebs,
#        ebs: {
#          hvm: true,
#          size: 10,
#          region: 'us-east-1',
#          copy_regions: [],
#          account_ids: []
#        }
#      },
#    }

  def secrets
    @secrets ||= begin
      secrets_path = ENV['LINECOOK_SECRETS_PATH'] || SECRETS_PATH
      if File.exists?(secrets_path)
        ejson_path = File.join(Gem::Specification.find_by_name('ejson').gem_dir, 'build', "#{Linecook::Config.platform}-amd64", 'ejson' )
        command = "#{ejson_path} decrypt #{secrets_path}"
        secrets = JSON.load(`sudo #{command}`)
        secrets.deep_symbolize_keys
      else
        {}
      end
    end
  end
end
