module Linecook

  module Builder
    LXC_MIN_VERSION = '1.0.7'
    def backend
      backend_for_platform
    end

  private

    def backend_for_platform
      case Config.platform
      when 'linux'
        LinuxBuilder.backend
      when 'darwin'
        OSXBuilder.backend
      else
        fail "Cannot find supported backend for #{Config.platform}"
      end
    end

    def fetch_base_image
    end

  end

  module LinuxBuilder

    def backend
      check_lxc_version
    end

  private

    def check_lxc_version
      version = `lxc-info --version`
      fail "lxc too old (<#{LXC_MIN_VERSION}) or not present" unless Gem::Version.new(version) >= Gem::Version.new(LXC_MIN_VERSION)
    end
  end


  module OSXBuilder
    def backend
      require 'xhyve'
    end

  private

    def launch_sudo
      #/usr/bin/osascript -e 'do shell script "/path/to/myscript args 2>&1 etc" with administrator privileges'
    end
  end
end
