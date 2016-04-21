module Linecook
  module LinuxBuilder
    extend self

    def backend
      config = Linecook.config[:builder]
      images = Linecook.config[:image][:images]
      Linecook::Lxc::Container.new(name: config[:name], home: config[:home], image: config[:image], bridge: true)
    end
  end
end
