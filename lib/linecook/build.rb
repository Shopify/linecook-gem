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
      @ssh ||= Linecook::SSH.new(@container.ip, username: 'ubuntu', password: 'ubuntu', proxy: Linecook::Builder.ssh, keyfile: Linecook::SSH.private_key)
    end

    def snapshot(download: false)
      path = "/tmp/#{@name}-#{Time.now.to_i}.squashfs"
      Linecook::Builder.ssh.run("sudo mksquashfs #{@container.root} #{path} -wildcards -e 'usr/src' 'var/lib/apt/lists/archive*' 'var/cache/apt/archives'") # FIXME make these excludes dynamic based on OS
      Linecook::Builder.ssh.download(path, local: File.join(Linecook::ImageManager::IMAGE_PATH, File.basename(path))) if download
    end
  end
end
