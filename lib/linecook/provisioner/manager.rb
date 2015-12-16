require 'securerandom'

require 'linecook/builder/build'
require 'linecook/provisioner/chef-zero'

module Linecook
  module Baker
    extend self

    def bake(name: 'test', image: nil)
      image = image || Linecook::Config.load_config[:provisioner][:default_image]
      build = Linecook::Build.new(name)
      provider.provision(build)
    end

  private

    def provider
      name = Linecook::Config.load_config[:provisioner][:provider]
      case name
      when :chefzero
        Linecook::Chef
      else
        fail "Unsupported provisioner #{name}"
      end
    end
  end
end
