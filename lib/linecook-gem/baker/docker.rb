require 'tmpdir'
require 'fileutils'

require 'docker'

require 'linecook-gem/image'
require 'linecook-gem/util/locking'
require 'linecook-gem/util/common'

module Linecook
  module Baker
    # FIXME - refactor into a base class with an interface
    class Docker
      include Locking

      RETAIN_IMAGES = 3 # number of latest images to retain

      attr_reader :config

      def initialize(image, config)
        @image = image
        @config = config
        munge_config
      end


      def save
        FileUtils.mkdir_p(File.dirname(@image.path))
        with_retries(5) do
          # You might be wondering "wtf is this"? And how!
          # tl;dr, we want to take the bitwise OR of the return codes for everything in the pipe.
          # so, if any command in the pipe fails, treat the whole pipe to have failed.
          # otherwise, we could end up with xz compressing an invalid export, and treating it as OK.
          status = system("/bin/bash -c 'docker export #{@image.id} | xz -T 0 -0 > #{@image.path}; exit $((${PIPESTATUS[0]} | ${PIPESTATUS[1]}))'")
          fail "Export failed" unless status
        end
      end

      def instance
        @instance ||= @config.instances.find {|x| @image.name == x.suite.name }
      end

      def converge
        if @inherited
          begin
            instance.create
          rescue
            puts "Disabling docker cache"
            # Disable the cache and retry if we ran into a problem
            driver_config = instance.driver.send(:config)
            driver_config[:use_cache] = false

            with_retries(5) do
              instance.create
            end
          end
        end
        instance.converge
      ensure
        unlock("create_#{@inherited.id}") if @inherited
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
        @inherited = image
      end

    private

      def container
        @container ||= ::Docker::Container::get(@image.id)
      end

      def image_exists?(image)
        images=`docker images --format "{{.Repository}}:{{.Tag}}"`.lines.map(&:strip)
        images.include?("#{image.group}:#{image.tag}")
      end

      def import(image)
        lock("import_#{image.id}")
        if image_exists?(image)
          puts "Image #{image.id} has already been imported"
        else
          puts "Importing #{image.id}..."
          image.fetch
          open(image.path) do |io|
            ::Docker::Image.import_stream(repo: image.group, tag: image.tag, changes: ['CMD ["/sbin/init"]']) do
              io.read(Excon.defaults[:chunk_size] * 10 ) || ""
            end
          end
        end
      ensure
        unlock("import_#{image.id}")
      end


      # May the gods forgive us for all the rules this breaks
      def munge_config
        @data = @config.send(:data).instance_variable_get(:@data)
        @data[:driver][:instance_name] = @image.id
        suite = @data[:suites].find{ |n| n[:name] == @image.name }
        if suite && suite[:inherit]
          inherited = Linecook::Image.new(suite[:inherit][:name], suite[:inherit][:group], suite[:inherit][:tag])
          inherit(inherited)
          @data[:driver][:image] = "#{inherited.group}:#{inherited.tag}"
          @data[:driver][:provision_command] ||= []
          @data[:driver][:provision_command] << 'sed -i \'s/\(PasswordAuthentication no\)/#\1/g\' /etc/ssh/sshd_config'
        end
      end
    end
  end
end
