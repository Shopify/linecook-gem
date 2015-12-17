require 'securerandom'

require 'linecook/builder/build'
require 'linecook/provisioner/chef-zero'

module Linecook
  module Baker
    extend self

    def bake(name: nil, image: nil, snapshot: nil, upload: nil, package: nil, build: nil)
      build_agent = Linecook::Build.new(name, image: image)
      provider.provision(build_agent, name) if build
      snapshot = build_agent.snapshot(save: true) if snapshot ||  upload || package
      Linecook::ImageManager.upload(snapshot) if upload || package
      Linecook::Packager.package(snapshot) if package
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
