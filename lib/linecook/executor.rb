module Linecook
  module Executor
    def capture(command, sudo: true)
      execute(command, sudo: sudo, capture: true)
    end

    def test(check)
      if @remote
        return @remote.test(check)
      else
        `#{check}`
        return $?.exitstatus == 0
      end
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
end
