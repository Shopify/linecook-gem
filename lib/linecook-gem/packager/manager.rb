require 'linecook-gem/packager/ebs'

module Linecook
  module Packager
    extend self

    def package(image, type: type, **args)
      provider.package(image, type: type, **args)
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
