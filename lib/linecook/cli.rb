require 'thor'
require 'linecook'

module Linecook
  class CLI < Thor

    desc 'bake', 'Bake a new image'
    def bake
      Linecook::Baker.bake
    end

  end
end
