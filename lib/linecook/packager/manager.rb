require 'linecook/packager/ebs'

module Linecook
  module Packager
    extend self

    def package(image, type: type)
      provider.package(image, type: type)
    end

  private
    def provider
      name = Linecook.config[:packager][:provider]
      config = Linecook.config[:packager][name]
      case name
      when :ebs
        Linecook::Packager::EBS.new(**config)
      else
        fail "No packager implemented for for #{name}"
      end
    end
  end
end
