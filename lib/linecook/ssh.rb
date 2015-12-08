require 'sshkit'
require 'sshkit/dsl'

require 'linecook/config'

module Linecook
  class SSHKit::Formatter::Linecook < SSHKit::Formatter::Pretty

    def write_command(command)
      log_command_start(command) unless command.started?
      log_command_stdout(command) unless command.stdout.empty?
      log_command_stderr(command) unless command.stderr.empty?
      log_command_finished(command) if command.finished?
    end

    def log_command_start(command)
      print(command, 'run'.colorize(:green), command.to_s.colorize(:yellow))
    end

    def log_command_stdout(command)
      command.stdout.lines.each do |line|
        print(command, 'out'.colorize(:green), line)
      end
      command.stdout = ''
    end

    def log_command_stderr(command)
      command.stderr.lines.each do |line|
        print(command, 'err'.colorize(:yellow), line)
      end
      command.stderr = ''
    end

    def log_command_finished(command)
      if command.failure?
        print(command, 'failed'.colorize(:red), "with status #{command.exit_status} #{command.to_s.colorize(:yellow)} in #{sprintf('%5.3f seconds', command.runtime)}")
      else
        print(command, 'done'.colorize(:green), "#{command.to_s.colorize(:yellow)} in #{sprintf('%5.3f seconds', command.runtime)}")
      end
    end

    def print(command, state, message)
      line = "[#{command.host.to_s.colorize(:blue)}][#{state}] #{message}"
      line << ?\n unless line.end_with?(?\n)
      original_output << line
    end
  end

  class SSH

    def initialize(hostname, username: 'ubuntu', password: nil,  proxy: nil)
      @username = username
      @password = password
      @hostname = hostname
      @proxy = proxy
    end

    def test(check)
      result = nil
      on linecook_host do |host|
        result = test(check)
      end
      return result
    end

    def run(command)
      on linecook_host do |host|
        execute(command)
      end
    end

    def capture(command)
      output = nil
      on linecook_host do |host|
        output = capture(command)
      end
      return output
    end

    def upload(data, path)
      on linecook_host do |host|
        contents = File.exists?(data) ? data : StringIO.new(data)
        upload! contents, path
      end
    end

  private

    # in a thread:
    #Net::SSH.start( 'host' ) do |session|
    #  session.forward.local( 1234, 'www.google.com', 80 )
    #  session.loop
    #end
    def linecook_host
      @host ||= begin

        host = SSHKit::Host.new(user: @username , hostname: @hostname)
        host.password = @password if @password

        if @proxy
          ssh_command = "ssh #{@proxy[:username]}@#{@proxy[:hostname]} nc %h %p"
          proxy_cmd = Net::SSH::Proxy::Command.new(ssh_command)
          host.ssh_options = { proxy: proxy_cmd }
        end

        host
      end
    end
  end
end

SSHKit.config.output = SSHKit::Formatter::Linecook.new($stdout)
