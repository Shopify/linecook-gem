require 'kitchen'

def load_config(directory)
  @config ||= begin
    Dir.chdir(directory) do
      Kitchen::Config.new(
        kitchen_root: Dir.pwd,
        loader: Kitchen::Loader::YAML.new(
          project_config: ENV['KITCHEN_YAML'] || File.join(Dir.pwd, '.kitchen.yml'),
          local_config: ENV['KITCHEN_LOCAL_YAML'],
          global_config: ENV['KITCHEN_GLOBAL_YAML']
        )
      )

    end
  end
end



def with_retries(retries, sleep_duration: 5, &block)
  attempts = 0
  while attempts < retries
    begin
      return yield
    rescue => e
      puts "Retrying a failed action, error was:"
      puts e.message
      sleep sleep_duration
    ensure
      attempts += 1
    end
  end

  fail "Retries exceed (#{retries})"
end
