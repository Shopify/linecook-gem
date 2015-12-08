require 'linecook/builder'

module Linecook
  class Build

    def initialize(name, image)
      @builder = Linecook::Builder
      @ssh = @builder.ssh
      @name = name
      @container = Linecook::Lxc::Container.new(name: name, image: image, remote: @ssh)
    end

    def start
      @container.start
    end

    def stop
      @container.stop
    end

  end
end
