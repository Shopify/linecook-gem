require 'securerandom'

require 'linecook/builder/build'
require 'linecook/provisioner/chef-zero'

module Linecook
  module Baker
    extend self

    def bake(name: 'test', image: nil)
      build = Linecook::Build.new(name, image: image)
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
