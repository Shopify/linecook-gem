require 'forwardable'
require 'linecook/builder/manager'

module Linecook
  class Build
    extend Forwardable

    def_instance_delegators :@container, :stop, :start, :ip, :info

    def initialize(name, tag: nil, image: nil)
      Linecook::Builder.start
      @id = tag ? "#{name}-#{tag}" : name
      @image = image || Linecook.config[:provisioner][:default_image]
      @container = Linecook::Lxc::Container.new(name: @id, image: @image, remote: Linecook::Builder.ssh)
    end

    def ssh
      @ssh ||= Linecook::SSH.new(@container.ip, username: 'ubuntu', password: 'ubuntu', proxy: Linecook::Builder.ssh, keyfile: Linecook::SSH.private_key)
    end

    def snapshot(save: false)
      path = "/tmp/#{@id}-#{Time.now.to_i}.squashfs"
      @container.pause
      Linecook::Builder.ssh.run("sudo mksquashfs #{@container.root} #{path} -wildcards -e 'usr/src' 'var/lib/apt/lists/archive*' 'var/cache/apt/archives'") # FIXME make these excludes dynamic based on OS
      @container.resume
      path = if save
        local_path = File.join(Linecook::ImageManager::IMAGE_PATH, File.basename(path))
        Linecook::Builder.ssh.download(path, local: local_path)
        Linecook::Builder.ssh.run("sudo rm -f #{path}")
        local_path
      else
        path
      end
    end
  end
end
