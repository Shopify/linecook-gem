def with_retries(retries, &block)
  attempts = 0
  while attempts < retries
    begin
      yield
    rescue => e
      puts "Retrying a failed action, error was:"
      puts e.message
      puts e.backtrace
    ensure
      attempts += 1
    end
  end
end
