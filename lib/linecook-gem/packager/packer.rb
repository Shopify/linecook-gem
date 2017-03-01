require 'json'
require 'mkmf'
require 'fileutils'
require 'open-uri'
require 'tempfile'
require 'tmpdir'
require 'pty'

require 'linecook-gem/image'
require 'linecook-gem/util/downloader'
require 'linecook-gem/util/locking'
require 'linecook-gem/util/common'

module Linecook
  class Packer

    include Downloader
    include Locking

    SOURCE_URL = 'https://releases.hashicorp.com/packer/'
    PACKER_VERSION = '0.12.0'
    PACKER_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'bin', 'packer')

    def initialize(config)
      system("#{packer_path} --version")
    end

    def package(image, directory)
      @image = image
      kitchen_config = load_config(directory).send(:data).instance_variable_get(:@data)
      image_config = kitchen_config[:suites].find{ |x| x[:name] == image.name }
      if image_config && image_config[:packager]
        packager = image_config[:packager] || {}
      end
      conf_file = Tempfile.new("#{@image.id}-packer.json")
      config = generate_config(packager)
      conf_file.write(config)
      conf_file.close
      output = []
      PTY.spawn("sudo #{PACKER_PATH} build -machine-readable #{conf_file.path}") do |stdout, _, _|
        begin
          stdout.each do |line|
            output << line if line =~ /artifact/
            tokens = line.split(',')
            if tokens.length > 4
              out = tokens[4].gsub('%!(PACKER_COMMA)', ',')
              time = DateTime.strptime(tokens[0], '%s').strftime('%c')
              puts "#{time} | #{out}"
            else
              puts "unexpected output format"
              puts tokens
            end
          end
        rescue Errno::EIO
          puts "Packer finshed executing"
        end
      end
      extract_artifacts_from_output(output)
    ensure
      conf_file.close
      conf_file.unlink
    end

  private

    def build_provisioner(chroot_commands)
      provisioner = [
        {
          type: 'shell',
          inline: chroot_commands
        }
      ]
    end

    def packer_path
      @path ||= begin
        found = File.exists?(PACKER_PATH) ? PACKER_PATH : find_executable('packer')
        path = if found
          version = `#{found} --version`
          Gem::Version.new(version) >= Gem::Version.new(PACKER_VERSION) ? found : nil
        end
        path ||= get_packer
      end
    end

    def get_packer
      puts "packer too old (<#{PACKER_VERSION}) or not present, getting latest packer"
      arch = 1.size == 8 ? 'amd64' : '386'

      FileUtils.rm_f(Dir[File.join(File.dirname(PACKER_PATH), "*")])
      path = File.join(File.dirname(PACKER_PATH), 'packer.zip')
      url = File.join(SOURCE_URL, PACKER_VERSION, "packer_#{PACKER_VERSION}_linux_#{arch}.zip")
      download(url, path)
      unzip(path)
      PACKER_PATH
    end

  end
end
