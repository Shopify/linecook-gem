require 'securerandom'
require 'linecook/image/manager'
# FIXME: read config values from config file
#  - create cache loopback image
#   - dd, based on config file.


module Linecook
  module OSXBuilder
    extend self
    def backend
      XhyveBackend.new
    end
  end

  class XhyveBackend
    RUN_SPEC_PATH = File.join(Linecook::Config::LINECOOK_HOME, 'xhyve.yml').freeze
    LINUX_CMDLINE = 'boot=live root=/dev/ram0 live-media=initramfs console=ttyS1,115200 console=tty0 net.ifnames=0 biosdevname=0'.freeze

    attr_reader :ip
    def initialize
      spec = load_run_spec
      @pid = spec[:pid]
      @ip = spec[:ip]
      @uuid = spec[:uuid]
    end

    def info
      {ip: @ip, pid: @pid, uuid: @uuid}
    end

    def start
      launch_guest unless running?
    end

    def stop
      return false unless @pid
      Process.kill('KILL', @pid)
      @ip = nil
      @pid = nil
      save_run_spec
    end

    def running?
      return false unless @pid
      (true if Process.kill(0, @pid) rescue false)
    end

  private

    def launch_guest
      get_iso
      boot_path = File.join(mount_iso, 'BOOT')
      puts "Starting xhyve guest..."
      @uuid ||= SecureRandom.uuid
      guest = Xhyve::Guest.new(
          kernel: File.join(boot_path, 'VMLINUZ'),
          initrd: File.join(boot_path, 'INITRD'),
          cmdline: LINUX_CMDLINE,   # boot flags to linux
          #blockdevs: 'loop.img',     # path to img files to use as block devs # FIXME
          uuid: @uuid,
          serial: 'com2',
          memory: '4G', # FIXME
          processors: 1,             # number of processors #FIXME
          networking: true,          # Enable networking? (requires sudo)
          acpi: true,                 # set up acpi? (required for clean shutdown)
          )
      guest.start
      puts "Started with #{guest.mac}... waiting for network"
      @ip = guest.ip
      @pid = guest.pid
      unless @ip
        @guest.kill
        fail 'Could not acquire ip' 
      end
      puts "Network acquired, IP is #{@ip}"
      save_run_spec
      # wait_ssh # FIXME: we need to wait until SSH is actually up or we will sometimes timeout
    end

    # get and mount the iso
    def get_iso
      @image_path = Linecook::ImageManager.fetch(:live_iso, profile: :public)
    end

    def mount_iso
      `hdiutil mount #{@image_path}`.strip.split(/\s+/).last
    end

    def save_run_spec
      File.write(RUN_SPEC_PATH, YAML.dump(info))
    end

    def load_run_spec
      File.exists?(RUN_SPEC_PATH) ? YAML.load(File.read(RUN_SPEC_PATH)) : {}
    end
  end
end
