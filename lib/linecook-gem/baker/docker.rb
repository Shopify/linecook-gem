require 'tmpdir'
require 'fileutils'

require 'docker'

require 'linecook-gem/image'

module Linecook
  module Baker
    # FIXME - refactor into a base class with an interface
    class Docker

      attr_reader :config

      def initialize(image, config)
        @image = image
        @config = config
        munge_config
      end


      def save
        FileUtils.mkdir_p(File.dirname(@image.path))
        container.stop
        system("docker export #{@image.id} | xz -T 0 -0 > #{@image.path}")
      end

      def instance
        @instance ||= @config.instances.find {|x| @image.name == x.suite.name }
      end

      def converge
        instance.converge
      end

      def destroy
        container.delete(force: true)
        instance.destroy
      rescue ::Docker::Error::NotFoundError => e
        puts e.message
      end

      def exec(command)
        command = ['/bin/bash', '-c', command]
        container.exec(command, tty: true)
      end

      def inherit(image)
        puts "Inheriting from #{image.id}..."
        import(image) unless image_exists?(image)
        clean_older_images(image)
      end

    private
      def container
        @container ||= ::Docker::Container::get(@image.id)
      end

      def image_exists?(image)
        ::Docker::Image.all.find do |docker_image|
          docker_image.info['RepoTags'].first == "#{image.group}:#{image.tag}"
        end
      end

      def clean_older_images(image)
        puts "Cleaning up older images for #{image.group}..."
        older_images(image).each do |old|
          children(old).each do |child|
            remove_docker_image(child)
          end
          remove_docker_image(old)
        end
      end

      def remove_docker_image(docker_image)
        puts "Removing #{docker_image.id}"
        docker_image.remove(force: false)
      rescue ::Docker::Error::ConflictError => e
        puts "Failed to remove #{docker_image.id}"
        puts e.message
      end

      def children(parent_image)
        ::Docker::Image.all.select do |docker_image|
          docker_image.info['ParentId'] == parent_image.id
        end.compact
      end

      def older_images(image)
        ::Docker::Image.all.select do |docker_image|
          group, tag = docker_image.info['RepoTags'].first.split(':')
          group == image.group && tag.to_i < image.tag.to_i
        end
      end

      def import(image)
        puts "Importing #{image.id}..."
        image.fetch
        open(image.path) do |io|
          ::Docker::Image.import_stream(repo: image.group, tag: image.tag, changes: ['CMD ["/sbin/init"]']) do
            io.read(Excon.defaults[:chunk_size] * 10 ) || ""
          end
        end
      end


      # May the gods forgive us for all the rules this breaks
      def munge_config
        data = @config.send(:data).instance_variable_get(:@data)
        data[:driver][:instance_name] = @image.id
        suite = data[:suites].find{ |n| n[:name] == @image.name }
        if suite && suite[:inherit]
          inherited = Linecook::Image.new(suite[:inherit][:name], suite[:inherit][:group], suite[:inherit][:tag])
          inherit(inherited)
          data[:driver][:image] = "#{inherited.group}:#{inherited.tag}"
          data[:driver][:provision_command] ||= []
          data[:driver][:provision_command] << 'sed -i \'s/\(PasswordAuthentication no\)/#\1/g\' /etc/ssh/sshd_config'
        end
      end
    end
  end
end
