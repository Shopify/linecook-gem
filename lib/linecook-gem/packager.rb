
require 'linecook-gem/image'
require 'linecook-gem/packager/packer'
require 'linecook-gem/packager/squashfs'
require 'kitchen/configurable'


module Linecook
  module Packager
    extend self

    def package(image, name: 'packer', directory: nil)
      image.fetch
      provider(name.to_sym).package(image, directory)
    end

  private
    def provider(name)
      config = Linecook.config[:packager][name]
      case name
      when :packer
        Linecook::AmiPacker.new(**config)
      when :squashfs
        Linecook::Squashfs.new(**config)
      else
        fail "No packager implemented for for #{name}"
      end
    end
  end
end
