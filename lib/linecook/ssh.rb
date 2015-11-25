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

  module SSH
    extend self
    def run(command)
      on linecook_host do |host|
        execute(command)
      end
    end

    def upload(data, path)
      on linecook_host do |host|
        contents = StringIO.new(data)
        upload! contents, path
      end
    end

  private

    def linecook_host
      @host ||= begin
        host_config = Linecook::Config.load_config[:host]
        host = SSHKit::Host.new("#{host_config[:username]}@#{host_config[:hostname]}")
        host.password = host_config[:password]
        host
      end
    end
  end
end

SSHKit.config.output = SSHKit::Formatter::Linecook.new($stdout)
