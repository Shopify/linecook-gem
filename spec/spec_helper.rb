require 'simplecov'
SimpleCov.start
require 'rspec'
require 'digest'
require 'ipaddress'

require File.expand_path('../../lib/linecook.rb', __FILE__)

FIXTURE_PATH = File.expand_path('../fixtures', __FILE__)

def with_container(**opts)
  container = Linecook::Lxc::Container.new(opts || {})
  container.start
  yield container
  container.stop
end

def match_fixture(name, actual)
  path = File.expand_path("fixtures/#{name}.txt", File.dirname(__FILE__))
  File.open(path, 'w') { |f| f.write(actual) } if ENV['FIXTURE_RECORD']
  expect(actual.strip).to eq(File.read(path).strip)
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
