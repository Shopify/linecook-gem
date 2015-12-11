require 'linecook/ssh'
require 'linecook/image'
require 'linecook/config'
require 'tempfile'
require 'ipaddress'

module Linecook
  module Lxc
    class Container
      MAX_WAIT = 60
      attr_reader :config, :root
      def initialize(name: 'linecook', home: '/u/lxc', image: nil, remote: :local)
        @name = name
        @home = home
        @remote = remote == :local ? false : remote
        @root = File.join(@home, @name, 'rootfs')
        config = { utsname: name, rootfs: @root }
        config.merge!(network: { type: 'veth', flags: 'up', link: 'lxcbr0' }) # FIXME
        @config = Linecook::Lxc::Config.generate(config) # FIXME read link from config
        @source_image = image || Linecook::Config.load_config[:images][:base_image]
      end

      def start
        setup_image
        setup_dirs
        mount_all
        write_config
        execute("lxc-start #{container_str} -d")
        wait_running
        # Don't start a cgmanager if we're already in a container
        execute('[ -f /etc/init/cgmanager.conf ] && sudo status cgmanager | grep -q running && sudo stop cgmanager || true') if lxc?
        setup_bridge unless @remote
        wait_ssh
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
        info[:ip].is_a?(Array) ? info[:ip].find { |ip| bridge_network.include?(IPAddress(ip)) } : info[:ip]
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

      def wait_running
        wait_for { running? }
      end
      def wait_ssh
        wait_for { capture("lxc-attach -n #{@name} -P #{@home} status ssh || true") =~ /running/ }
      end

      def wait_for
        attempts = 0
        until attempts > MAX_WAIT
          break if yield
          attempts += 1
          sleep(1)
        end
      end

      def lxc?
        namespaces = capture('cat /proc/1/cgroup').lines.map{ |l| l.strip.split(':').last }.uniq
        namespaces.length != 1 || namespaces.first != '/'
      end

      def setup_dirs
        @lower_dir = tmpdir(label: 'lower')
        @upper_base = tmpdir(label: 'upper')
        @upper_dir = File.join(@upper_base, '/upper')
        @work_dir = File.join(@upper_base, '/work')
        @socket_dirs = []
        (Linecook::Config.load_config[:socket_dirs] ||[]).each{ |sock| @socket_dirs << File.join(@root, sock) }
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

      def mount_all
        # Prepare an overlayfs
        execute("mkdir -p #{@root}")
        execute("mkdir -p #{@lower_dir}")
        execute("mkdir -p #{@upper_base}")
        mount(@image_path, @lower_dir, options: '-o loop')
        mount('tmpfs', @upper_base, type: '-t tmpfs', options:'-o noatime') # FIXME: - don't always be tmpfs
        execute("mkdir -p #{@work_dir}")
        execute("mkdir -p #{@upper_dir}")
        mount('overlay', @root, type: '-t overlay', options: "-o lowerdir=#{@lower_dir},upperdir=#{@upper_dir},workdir=#{@work_dir}")
        # Overlayfs doesn't support unix domain sockets
        @socket_dirs.each do |sock|
          execute("mkdir -p #{sock}")
          mount('tmpfs', sock, type: '-t tmpfs', options:'-o noatime')
        end
      end

      def mount(source, dest, type: '', options:'')
        execute("grep -q #{dest} /etc/mtab || sudo mount #{type} #{options} #{source} #{dest}")
      end

      def unmount
        @socket_dirs.each { |sock| execute("umount #{sock}") }
        execute("umount #{@root}")
        execute("umount #{@upper_base}")
        execute("umount #{@lower_dir}")
        execute("rmdir #{@lower_dir}")
        execute("rmdir #{@upper_base}")
      end

      def bridge_network
        broad_ip = Socket.getifaddrs.find do |a|
          a.name == 'lxcbr0' && a.broadaddr && a.broadaddr.afamily == 2 && !a.broadaddr.inspect_sockaddr.start_with?('169.254')
        end.broadaddr.inspect_sockaddr
        IPAddress("#{broad_ip.to_s}/24")
      end

      def setup_bridge
        bridge_config = <<-eos
auto lo
iface lo inet loopback

auto lxcbr0
iface lxcbr0 inet dhcp
  bridge_ports eth0
  bridge_fd 0
  bridge_maxwait 0
eos
        interfaces = Tempfile.new('interfaces')
        interfaces.write(bridge_config)
        interfaces.close
        execute("mv #{interfaces.path} #{File.join(@root, 'etc', 'network', 'interfaces')}")

        execute("lxc-attach -n #{@name} -P #{@home} ifup lxcbr0")
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
          link: 'br0'
        },
        mount: {
          auto: 'cgroup'
        },
        cgroup: {
          devices: {
            allow: [
              'b 7:* rwm',
              'c 10:237 rwm'
            ]
          }
        }
      }.freeze

      def generate(**kwargs)
        cfg = []
        flatten(DEFAULT_LXC_CONFIG.merge(kwargs || {})).each do |k, v|
          [v].flatten.each do |val|
            cfg << "lxc.#{k}=#{val}"
          end
        end
        cfg.join("\n")
      end

      private

      def flatten(hash)
        flattened = {}
        hash.each do |k, v|
          if v.is_a?(Hash)
            flatten(v).each do |key, val|
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
