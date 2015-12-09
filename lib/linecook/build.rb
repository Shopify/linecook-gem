require 'forwardable'
require 'linecook/builder'

module Linecook
  class Build
    extend Forwardable

    def_instance_delegators :@container, :stop, :ip, :info

    def initialize(name, image)
      Linecook::Builder.start
      @ssh = Linecook::Builder.ssh
      @name = name
      @container = Linecook::Lxc::Container.new(name: name, image: image, remote: @ssh)
    end

    def start
      @container.start
    end
  end
end
