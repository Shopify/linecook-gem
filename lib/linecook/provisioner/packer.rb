require 'json'
require 'tempfile'
require 'mkmf'
require 'fileutils'

require 'linecook/util/executor'


module Linecook
  module Packer
    def self.provision(build, role)
      Runner.new(build, role).run
    end

    class Runner
      SOURCE_URL = 'https://releases.hashicorp.com/packer/'
      PACKER_VERSION = '0.8.6'
      PACKER_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'bin', 'packer')

      include Executor

      def initialize(build, role)
        role_config = Linecook::Config.load_config[:roles][role.to_sym]
        @packer = packer_path
        @build = build
        @template = role_config[:template_path]
      end

      def run
        @build.start
        packer_template = inject_builder
        Tempfile.open('packer-linecook') do |template|
          template.write(JSON.dump(packer_template))
          template.flush
          execute("#{@packer} build #{template.path}", sudo: false)
        end
      end

    private

      def packer_path
        found = File.exists?(PACKER_PATH) ? PACKER_PATH : find_executable('packer')
        path = if found
          version = execute("#{found} --version", sudo: false, capture: true)
          Gem::Version.new(version) >= Gem::Version.new(PACKER_VERSION) ? found : nil
        end

        path ||= get_packer
      end

      def get_packer
        puts "packer too old (<#{PACKER_VERSION}) or not present, getting latest packer"
        arch = 1.size == 8 ? 'amd64' : '386'
        path = File.join(File.dirname(PACKER_PATH), 'packer.zip')
        url = File.join(SOURCE_URL, PACKER_VERSION, "packer_#{PACKER_VERSION}_#{Linecook::Config.platform}_#{arch}.zip")
        Linecook::Downloader.download(url, path)
        Linecook::Downloader.unzip(path)
        PACKER_PATH
      end

      def inject_builder
        packer_template = JSON.load(File.read(@template)).symbolize_keys
        packer_template.merge(builders: null_builder)
      end

      def null_builder
        [ communicator.merge(type: 'null') ]
      end

      def communicator
        {
          ssh_host: @build.ssh.hostname,
          ssh_username: @build.ssh.username,
          ssh_private_key_file: @build.ssh.keyfile,
          ssh_bastion_host: Linecook::Builder.ssh.hostname,
          ssh_bastion_username: Linecook::Builder.ssh.username,
          ssh_bastion_private_key_file: Linecook::Builder.ssh.keyfile,
        }
      end
    end
  end
end
