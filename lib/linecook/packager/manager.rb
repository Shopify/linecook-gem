require 'linecook/packager/ebs'

module Linecook
  module Packager
    extend self

    def package(image)
      provider.package(image)
    end

  private
    def provider
      name = Linecook::Config.load_config[:packager][:provider]
      config = Linecook::Config.load_config[:packager][name]
      case name
      when :ebs
        Linecook::Packager::EBS.new(**config)
      else
        fail "No packager implemented for for #{name}"
      end
    end
  end
end
