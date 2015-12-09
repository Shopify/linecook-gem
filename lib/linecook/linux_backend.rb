module Linecook
  module LinuxBuilder
    extend self
    LXC_MIN_VERSION = '1.0.7'

    def backend
      check_lxc_version
      config = Linecook::Config.load_config[:builder]
      images = Linecook::Config.load_config[:images]
      Linecook::Lxc::Container.new(name: config[:name], home: config[:home], image: images[config[:image]])
    end

  private

    # FIXME: move to dependency check during initial setup if on linux
    def check_lxc_version
      version = `lxc-info --version`
      fail "lxc too old (<#{LXC_MIN_VERSION}) or not present" unless Gem::Version.new(version) >= Gem::Version.new(LXC_MIN_VERSION)
    end
  end
end
