require 'forwardable'
require 'linecook/builder/manager'

module Linecook
  class Build
    extend Forwardable
    USERNAME = 'linecook'

    def_instance_delegators :@container, :start, :stop, :ip, :info
    attr_reader :type

    def initialize(name, tag: nil, image: nil, id: nil)
      Linecook::Builder.start
      @type = tag ? "#{name}-#{tag}" : name
      @id = id ? "#{@type}-#{id}" : @type
      @image = image || Linecook.config[:provisioner][:default_image]
      @container = Linecook::Lxc::Container.new(name: @id, image: @image, remote: Linecook::Builder.ssh)
    end

    def clean
      Linecook::ImageManager.clean(type: @image[:type]) if @image.is_a?(Hash) && @image[:type]
    end

    def ssh
      @ssh ||= Linecook::SSH.new(@container.ip, username: USERNAME, proxy: Linecook::Builder.ssh, keyfile: Linecook::SSH.private_key, setup: false)
    end

    def snapshot(save: false, resume: false)
      path = "/tmp/#{@id}-#{Time.now.to_i}.squashfs"
      @container.stop(destroy: false)
      Linecook::Builder.ssh.run("sudo mksquashfs #{@container.root} #{path} -wildcards -e 'usr/src' 'var/lib/apt/lists/archive*' 'var/cache/apt/archives'") # FIXME make these excludes dynamic based on OS
      @container.resume if resume
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
