require 'thor/shell'
require 'fileutils'
require 'kitchen'
require 'kitchen/command/test'

require 'linecook-gem/image'
require 'linecook-gem/baker/docker'

module Linecook
  module Baker
    class Baker

      def initialize(image, directory: nil)
        @directory = File.expand_path(directory || Dir.pwd)
        @image = image

        Dir.chdir(@directory) do
          load_config
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
        puts e.message
        puts e.backtrace
        raise
      ensure
        if keep
          puts "Preserving build #{@image.id}, you will need to clean it up manually."
        else
          puts "Cleaning up build #{@image.id}"
          FileUtils.rm_f(@directory, '.kitchen', "#{@driver.instance.name}.yml")
          @driver.instance.destroy
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
        if @is_chef
          @driver.exec('userdel -r -f kitchen')
          @driver.exec('groupdel kitchen')
          @driver.exec('rm -rf /etc/chef')
          @driver.exec('rm -rf /tmp/kitchen')
          @driver.exec('rm -f /etc/sudoers.d/kitchen')
        end
      end

      def load_config
        @config ||= begin

          Kitchen::Config.new(
            kitchen_root: @directory,
            loader: Kitchen::Loader::YAML.new(
              project_config: ENV['KITCHEN_YAML'] || File.join(@directory, '.kitchen.yml'),
              local_config: ENV['KITCHEN_LOCAL_YAML'],
              global_config: ENV['KITCHEN_GLOBAL_YAML']
            )
          )

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
