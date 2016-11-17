require 'thor/shell'
require 'fileutils'
require 'kitchen'
require 'kitchen/command/test'

require 'linecook-gem/image'
require 'linecook-gem/util/common'
require 'linecook-gem/baker/docker'

module Linecook
  module Baker
    class Baker

      def initialize(image, directory: nil)
        @directory = File.expand_path(directory || Dir.pwd)
        @image = image
        Dir.chdir(@directory) do
          @config = load_config(@directory)
          munge_config
          @driver = driver
        end

      end

      def bake(snapshot: nil, upload: nil, keep: nil)

        FileUtils.mkdir_p(File.join(Dir.pwd, '.kitchen'))

        Dir.chdir(@directory) { @driver.converge }

        snapshot ||= upload
        if snapshot
          puts 'Convergence complete, generating snapshot'
          save
          @image.upload if upload
        end

      rescue => e
        if e.cause
          puts "Original cause of exception:"
          puts e.cause.message
          puts e.cause.backtrace
        end

        puts e.message
        puts e.backtrace
        raise
      ensure
        if keep
          puts "Preserving build #{@image.id}, you will need to clean it up manually."
        else
          puts "Cleaning up build #{@image.id}"
          @driver.destroy
        end
      end

      def clean_kitchen
        Dir.chdir(@directory) do
          @config.instances.each do |instance|
            instance.destroy
          end
        end
      end

      def save
        puts "Saving image to #{@image.path}..."
        clean
        @driver.save
      end

    private

      def clean
        @driver.exec('rm -f /.docker*')
        if @is_chef
          @driver.exec('userdel -r -f kitchen')
          @driver.exec('groupdel kitchen')
          @driver.exec('rm -rf /etc/chef')
          @driver.exec('rm -rf /tmp/kitchen')
          @driver.exec('rm -f /etc/sudoers.d/kitchen')
        end
      end

      def munge_config
        data = @config.send(:data).instance_variable_get(:@data)
        @is_chef = data[:provisioner][:name] =~ /chef/
        if Linecook.config[:chef] &&
            Linecook.config[:chef][:encrypted_data_bag_secret] && @is_chef
          data[:provisioner][:data_bag_secret] = Linecook.config[:chef][:encrypted_data_bag_secret]
        end

      end

      def driver
        case @config.loader.read[:driver][:name]
        when 'docker'
          Linecook::Baker::Docker.new(@image, @config)
        end
      end
    end
  end
end
