require 'sshkit'
require 'sshkit/dsl'
require 'net/ssh'
require 'net/ssh/proxy/command'

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
      line << "\n" unless line.end_with?("\n")
      original_output << line
    end
  end

  class SSH

    attr_reader :username, :hostname
    def initialize(hostname, username: 'ubuntu', password: nil, proxy: nil)
      @username = username
      @password = password
      @hostname = hostname
      @proxy = proxy_command(proxy) if proxy
    end

    def forward(local, remote:nil)
      remote ||= local
      opts = { password: @password }
      opts.merge!({ proxy: @proxy }) if @proxy
      @session = Net::SSH.start(@hostname, @username, opts)
      @session.forward.remote(local, '127.0.0.1', remote)
      # Block to ensure it's open
      @session.loop { !@session.forward.active_remotes.include?([remote, '127.0.0.1']) }
      @keep_forwarding = true
      @forward = Thread.new do
        @session.loop(0.1) { @keep_forwarding }
      end
    end

    def stop_forwarding
      @keep_forwarding = false
      @forward.join
      @session.close unless @session.closed?
    end

    def test(check)
      result = nil
      on linecook_host do |_host|
        result = test(check)
      end
      result
    end

    def run(command)
      on linecook_host do |_host|
        execute(command)
      end
    end

    def capture(command)
      output = nil
      on linecook_host do |_host|
        output = capture(command)
      end
      output
    end

    def upload(data, path)
      on linecook_host do |_host|
        contents = File.exist?(data) ? data : StringIO.new(data)
        upload! contents, path
      end
    end

    private

    def linecook_host
      @host ||= begin

        host = SSHKit::Host.new(user: @username, hostname: @hostname)
        host.password = @password if @password
        host.ssh_options = { proxy: @proxy } if @proxy
        host
      end
    end

    def proxy_command(proxy)
      ssh_command = "ssh #{proxy.username}@#{proxy.hostname} nc %h %p"
      Net::SSH::Proxy::Command.new(ssh_command)
    end
  end
end

SSHKit.config.output = SSHKit::Formatter::Linecook.new($stdout)
