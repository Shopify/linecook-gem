require 'openssl'

require 'sshkit'
require 'sshkit/dsl'
require 'net/ssh'
require 'net/ssh/proxy/command'

require 'linecook/util/config'

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
    MAX_RETRIES = 5
    attr_reader :username, :password, :hostname, :keyfile

    def self.private_key
      userkey = File.expand_path("~/.ssh/id_rsa")
      dedicated_key = File.join(Linecook::Config::LINECOOK_HOME, 'linecook_ssh.pem')
      unless File.exists?(dedicated_key)
        File.write(dedicated_key, SSHKey.generate.private_key)
        FileUtils.chmod(0600, dedicated_key)
      end
      File.exists?(userkey) ? userkey : dedicated_key
    end

    def self.public_key(keyfile: nil)
      SSHKey.new(File.read(keyfile || private_key)).ssh_public_key
    end

    # Generate a fingerprint for an SSHv2 key used by amazon, yes, this is ugly
    def self.sshv2_fingerprint(key)
      _, blob = key.split(/ /)
      blob = blob.unpack("m*").first
      reader = Net::SSH::Buffer.new(blob)
      k=reader.read_key
      OpenSSL::Digest.new('md5',k.to_der).hexdigest.scan(/../).join(":")
    end

    def initialize(hostname, username: 'ubuntu', password: nil, keyfile: nil, proxy: nil, setup: true)
      @username = username
      @password = password
      @hostname = hostname
      @keyfile = keyfile
      @proxy = proxy_command(proxy) if proxy
      wait_for_connection
      setup_ssh_key if @keyfile && setup
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

    def download(path, local: nil)
      on linecook_host do |_host|
        download! path, local || File.basename(path)
      end
    end

    private

    def wait_for_connection
      puts "Waiting for SSH connection"
      attempts = 0
      while attempts < MAX_RETRIES
        begin
          run("echo connected")
          return
        rescue SSHKit::Runner::ExecuteError
          puts "Retrying SSH connection"
          sleep(5)
          attempts += 1
        end
      end
    end

    def setup_ssh_key
      pubkey = Linecook::SSH.public_key(keyfile: @keyfile)
      config = Linecook.config[:builder]
      run("mkdir -p /home/#{config[:username]}/.ssh")
      upload(pubkey, "/home/#{config[:username]}/.ssh/authorized_keys")
    end


    def linecook_host
      @host ||= begin
        host = SSHKit::Host.new(user: @username, hostname: @hostname)
        host.password = @password if @password
        opts = {}
        opts.merge!({ proxy: @proxy }) if @proxy
        opts.merge!({ keys: [@keyfile], auth_methods: %w(publickey password) }) if @keyfile
        host.ssh_options = opts
        host
      end
    end

    def proxy_command(proxy)
      ssh_command = "ssh #{"-i #{@keyfile}" if @keyfile} #{proxy.username}@#{proxy.hostname} nc %h %p"
      Net::SSH::Proxy::Command.new(ssh_command)
    end
  end
end

SSHKit.config.output = SSHKit::Formatter::Linecook.new($stdout)
