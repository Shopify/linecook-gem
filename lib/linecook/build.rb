require 'forwardable'
require 'linecook/builder'

module Linecook
  class Build
    extend Forwardable

    def_instance_delegators :@container, :stop, :start, :ip, :info

    def initialize(name, image)
      Linecook::Builder.start
      @name = name
      @image = image
      @container = Linecook::Lxc::Container.new(name: @name, image: @image, remote: Linecook::Builder.ssh)
    end

    def ssh
      @ssh ||= Linecook::SSH.new(@container.ip, username: 'ubuntu', password: 'ubuntu', proxy: Linecook::Builder.ssh, keyfile: Linecook::Builder.pemfile)
    end
  end
end
