require 'securerandom'

require 'linecook/build'
require 'linecook/chef'

module Linecook
  module Baker
    extend self

    def bake
      provisioner = 'chef' # FIXME HACK - read from config instead
      build = Linecook::Build.new('test', 'ubuntu-base.squashfs') # FIXME - HACK, read from config
      case provisioner
        when 'chef'
          Linecook::Chef.provision(build)
        else
          fail "Unsupported provisioner #{provisioner}"
      end
    end
  end
end
