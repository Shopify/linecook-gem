module Linecook
  module OSXBuilder
    extend self
    def backend
      require 'xhyve'
    end
  end
end
