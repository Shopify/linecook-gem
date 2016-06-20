
require 'linecook-gem/image'
require 'linecook-gem/packager/packer'
require 'kitchen/configurable'


module Linecook
  module Packager
    extend self

    def package(image)
      image.fetch
      provider.package(image)
    end

  private
    def provider
      name = Linecook.config[:packager][:provider]
      config = Linecook.config[:packager][name]
      case name
      when :packer
        Linecook::AmiPacker.new(**config)
      else
        fail "No packager implemented for for #{name}"
      end
    end
  end
end
