require 'forwardable'
require 'linecook/builder'

module Linecook
  class Build
    extend Forwardable

    def_instance_delegators :@container, :stop, :ip, :info

    def initialize(name, image)
      @builder = Linecook::Builder
      @ssh = @builder.ssh
      @name = name
      @container = Linecook::Lxc::Container.new(name: name, image: image, remote: @ssh)
    end

    def start
      @builder.start
      @container.start
    end
  end
end
