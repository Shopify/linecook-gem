require 'securerandom'
require 'fileutils'

require 'linecook/builder/build'
require 'linecook/provisioner/chef-zero'
require 'linecook/provisioner/packer'

module Linecook
  module Baker
    extend self

    def bake(name: nil, tag: nil, id: nil, snapshot: nil, upload: nil, package: nil, build: nil, keep: nil, clean: nil)
      build_agent = Linecook::Build.new(name, tag: tag, id: id)
      provider(name).provision(build_agent, name) if build
      snapshot = build_agent.snapshot(save: true) if snapshot ||  upload || package
      Linecook::ImageManager.upload(snapshot, type: build_agent.type) if upload || package
      Linecook::Packager.package(snapshot, type: build_agent.type) if package
    ensure
      build_agent.stop unless keep
      FileUtils.rm_f(snapshot) if clean
    end

  private

    def provider(name)
      provisioner = Linecook.config[:roles][name.to_sym][:provisioner] || Linecook.config[:provisioner][:default_provider]
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
