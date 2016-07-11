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
