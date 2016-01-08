require 'linecook/image/manager'
require 'linecook/util/ssh'
require 'linecook/util/config'
require 'linecook/util/executor'
require 'tempfile'
require 'ipaddress'

module Linecook
  module Lxc
    class Container

      include Executor
      MAX_WAIT = 60
      attr_reader :config, :root
      def initialize(name: 'linecook', home: '/u/lxc', image: nil, remote: :local, bridge: false)
        @name = name
        @home = home
        @bridge = bridge
        @remote = remote == :local ? false : remote
        @root = File.join(@home, @name, 'rootfs')
        config = { utsname: name, rootfs: @root }
        @config = Linecook::Lxc::Config.generate(config) # FIXME read link from config
        @source_image = image || :base_image
      end

      def start
        return if running?
        setup_image
        setup_dirs
        mount_all
        write_config
        execute("lxc-start #{container_str} -d")
        wait_running
        setup_bridge if @bridge
        wait_ssh
        unmount unless running?
      end

      def resume
        execute("lxc-start #{container_str} -d") unless running?
      end

      def stop(clean: false, destroy: true)
        setup_dirs
        if running?
          cexec("sudo userdel -r -f #{Linecook::Build::USERNAME}") if @remote
          execute("lxc-stop #{container_str} -k") if running?
        end
        unmount(clean: clean) if destroy
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
        capture("lxc-info #{container_str} || true").lines.each do |line|
          k, v = line.strip.split(/:\s+/)
          key = k.downcase.to_sym
          @info[key] = @info[key] ? [@info[key]].flatten << v : v
        end
        @info
      end

      private

      def cexec(command)
        execute("lxc-attach #{container_str} -- #{command}")
      end

      def wait_running
        wait_for { running? }
      end

      def wait_ssh
        if @remote
          user = Linecook::Build::USERNAME
          cexec("useradd -m -G sudo #{user} || true")
          cexec("mkdir -p /home/#{user}/.ssh")
          Linecook::Builder.ssh.upload(Linecook::SSH.public_key, "/tmp/#{@name}-pubkey")
          Linecook::Builder.ssh.run("sudo mv /tmp/#{@name}-pubkey #{@root}/home/#{user}/.ssh/authorized_keys")
          cexec("chown -R #{user} /home/#{user}/.ssh")
        end
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
        (Linecook.config[:socket_dirs] ||[]).each{ |sock| @socket_dirs << File.join(@root, sock) }
      end

      def write_config
        path = if @remote
                 file = Tempfile.new('lxc-config')
                 file.close
                 @remote.upload(@config, file.path)
                 file.path
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

      def unmount(clean: false)
        @socket_dirs.each { |sock| execute("umount #{sock}") }
        source = capture("mount | grep #{@lower_dir} | grep squashfs | awk '{print $1}'") if clean
        execute("umount #{@root}")
        execute("umount #{@upper_base}")
        execute("umount #{@lower_dir}")
        execute("rmdir #{@lower_dir}")
        execute("rmdir #{@upper_base}")

        # Clean up the source image, but only if it's not mounted elsewhre
        FileUtils.rm_f(source) if clean && capture("mount | grep #{source} || true").strip.empty?
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
        @source_path = Linecook::ImageManager.fetch(@source_image, profile: :public)
        if @remote
          name = File.basename(@source_path)
          dest = "/u/linecook/images/#{name}"
          unless test("[ -f #{dest} ]") && capture("shasum #{dest}").split.first == `shasum #{@source_path}`.split.first
            tmp = "/tmp/#{name}-#{SecureRandom.hex(4)}"
            @remote.run("sudo mkdir -p #{File.dirname(dest)}")
            @remote.upload(@source_path, tmp)
            @remote.run("sudo mv #{tmp} #{dest}")
          end
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
          link: 'lxcbr0'
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
