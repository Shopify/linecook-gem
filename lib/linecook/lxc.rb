require 'linecook/ssh'
require 'linecook/image'
require 'linecook/config'
require 'tempfile'
require 'ipaddress'

module Linecook
  module Lxc
    class Container
      attr_reader :config
      def initialize(name: 'linecook', home: '/u/lxc', image: nil, remote: :local)
        @remote = remote == :local ? false : remote
        config = { utsname: name, rootfs: File.join(home, name, 'rootfs') }
        config.merge!({ network: {type: 'veth', flags: 'up', link: 'lxcbr0'} }) if @remote # FIXME
        @config = Linecook::Lxc::Config.generate(config) # FIXME read link from config
        @source_image = image || Linecook::Config.load_config[:images][:base_image]
        @name = name
        @home = home
      end

      def start
        setup_image
        setup_dirs
        mount
        write_config
        execute("lxc-start #{container_str} -d")
        unmount unless running?
      end

      def stop
        setup_dirs
        execute("lxc-stop #{container_str} -k")
        unmount
      end

      def ip
        attempts = 10
        attempt = 0
        until info[:ip] || attempt >= attempts
          attempt += 1
          sleep(1)
        end
        info[:ip].is_a?(Array) ? info[:ip].find{ |ip| IPAddress("#{my_ip}/24").include?(IPAddress(ip))} : info[:ip]
      end

      def running?
        info[:state] == 'RUNNING'
      end

      def pid
        info[:pid]
      end

      def info
        @info = {}
        capture("lxc-info #{container_str}").lines.each do |line|
          k, v = line.strip.split(/:\s+/)
          key = k.downcase.to_sym
          @info[key] = @info[key] ? [@info[key]].flatten << v : v
        end
        @info
      end

    private

      def setup_dirs
        @lower_dir = tmpdir(label: 'lower')
        @upper_base = tmpdir(label: 'upper')
        @upper_dir = File.join(@upper_base, '/upper')
        @work_dir = File.join(@upper_base, '/work')
        @overlay = File.join(@home, @name, '/rootfs')
      end

      def write_config
        path = if @remote
          @remote.upload(@config, '/tmp/lxc-config')
          '/tmp/lxc-config'
        else
          file = Tempfile.new('lxc-config')
          file.write(@config)
          file.close
          file.path
        end
        execute("mv #{path} #{File.join(@home, @name, 'config')}")
      end

      def mount
        # Prepare an overlayfs
        execute("mkdir -p #{@overlay}")
        execute("mkdir -p #{@lower_dir}")
        execute("mkdir -p #{@upper_base}")
        execute("mount -o loop #{@image_path} #{@lower_dir}")
        execute("mount -t tmpfs tmpfs -o noatime #{@upper_base}") # FIXME - don't always be tmpfs
        execute("mkdir -p #{@work_dir}")
        execute("mkdir -p #{@upper_dir}")
        execute("mount -t overlay overlay -o lowerdir=#{@lower_dir},upperdir=#{@upper_dir},workdir=#{@work_dir} #{@overlay}")
      end

      def unmount
        execute("umount #{@overlay}")
        execute("umount #{@upper_base}")
        execute("umount #{@lower_dir}")
        execute("rmdir #{@lower_dir}")
        execute("rmdir #{@upper_base}")
      end

      def my_ip
        Socket.ip_address_list.find{|x| x.ipv4? && !x.ipv4_loopback? && !x.ip_address.start_with?('169.254')}.ip_address
      end

      def setup_image
        @source_path = Linecook::ImageFetcher.fetch(@source_image)
        if @remote
          dest = "#{File.basename(@source_path)}"
          @remote.upload(@source_path, dest) unless @remote.test("[ -f #{dest} ]")
          @image_path = dest
        else
          @image_path = @source_path
        end
      end

      def tmpdir(label: 'tmp')
        "/tmp/#{@name}-#{label}"
      end

      def container_str
        "-n #{@name} -P #{@home}"
      end

      def capture(command, sudo: true)
        execute(command, sudo: sudo, capture: true)
      end

      def execute(command, sudo: true, capture: false)
        command = "sudo #{command}" if sudo
        if @remote
          if capture
            return @remote.capture(command)
          else
            @remote.run(command)
          end
        else
          if capture
            return `#{command}`
          else
            system(command)
          end
        end
      end
    end

    module Config
      extend self
      DEFAULT_LXC_CONFIG = {
        include: '/usr/share/lxc/config/ubuntu.common.conf',
        aa_profile: 'lxc-container-default-with-nesting',
        arch: 'x86.64',
        utsname: 'linecook',
        rootfs: '/u/lxc/linecook/rootfs',
        network: {
          type: 'veth',
          flags: 'up',
          link: 'br0',
        },
        mount: {
          auto: 'cgroup',
        },
        cgroup: {
          devices: {
            allow: [
              'b 7:* rwm',
              'c 10:237 rwm',
            ]
          }
        }
      }.freeze

      def generate(**kwargs)
        cfg = []
        flatten(DEFAULT_LXC_CONFIG.merge(kwargs || {})).each do |k,v|
          [v].flatten.each do |val|
            cfg << "lxc.#{k}=#{val}"
          end
        end
        cfg.join("\n")
      end

    private
      def flatten(hash)
        flattened = {}
        hash.each do |k,v|
          if v.is_a?(Hash)
            flatten(v).each do |key,val|
              flattened["#{k}.#{key}"] = val
            end
          else
            flattened[k] = v
          end
        end
        flattened
      end
    end
  end
end

