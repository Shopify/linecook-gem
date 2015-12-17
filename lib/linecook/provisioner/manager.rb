require 'securerandom'

require 'linecook/builder/build'
require 'linecook/provisioner/chef-zero'
require 'linecook/provisioner/packer'

module Linecook
  module Baker
    extend self

    def bake(name: nil, image: nil, snapshot: nil, upload: nil, package: nil, build: nil)
      build_agent = Linecook::Build.new(name, image: image)
      provider(name).provision(build_agent, name) if build
      snapshot = build_agent.snapshot(save: true) if snapshot ||  upload || package
      Linecook::ImageManager.upload(snapshot) if upload || package
      Linecook::Packager.package(snapshot) if package
    end

  private

    def provider(name)
      provisioner = Linecook::Config.load_config[:roles][name.to_sym][:provisioner] || Linecook::Config.load_config[:provisioner][:default_provider]
      case provisioner
      when :chefzero
        Linecook::Chef
      when :packer
        Linecook::Packer
      else
        fail "Unsupported provisioner #{provisioner}"
      end
    end
  end
end
