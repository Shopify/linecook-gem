lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'linecook-gem/version'

Gem::Specification.new do |s|
  s.name        = 'linecook-gem'
  s.version     = Linecook::VERSION
  s.date        = '2015-11-24'
  s.summary     = 'Build system images using test kitchen'
  s.description = 'Build and snapshot a system image for distribution, CI, or both using real chef cookbooks and a fake server using test kitchen.'
  s.authors     = ['Dale Hamel']
  s.email       = 'dale.hamel@srvthe.net'
  s.files       = Dir['lib/**/*'] + Dir['man/**/*']
  s.executables = 'linecook'
  s.homepage    =
    'http://rubygems.org/gems/linecook'
  s.license = 'MIT'
  s.add_runtime_dependency 'activesupport', ['=4.2.5']
  s.add_runtime_dependency 'ruby-progressbar', ['~> 1.7']
  s.add_runtime_dependency 'ejson',  ['1.0.1']
  s.add_runtime_dependency 'aws-sdk',  ['~> 2.3']
  s.add_runtime_dependency 'rubyzip',  ['1.1.7']
  s.add_runtime_dependency 'rbnacl', ['~> 3.4', '>= 3.4.0']
  s.add_runtime_dependency 'docker-api', ['~> 1.29', '>= 1.29.0']
  s.add_runtime_dependency 'test-kitchen',  ['1.9.0']
  s.add_runtime_dependency 'kitchen-transport-docker',  ['~> 0.0.2', '>= 0.0.0']
  s.add_runtime_dependency 'kitchen-docker', ['~> 2.5', '>= 2.5.0']
  s.add_runtime_dependency 'rbnacl-libsodium', ['~> 1.0', '>= 1.0.0']
  s.add_development_dependency 'rake', ['=10.4.2']
  s.add_development_dependency 'simplecov', ['=0.10.0']
  s.add_development_dependency 'rspec', ['=3.4.0']
  s.add_development_dependency 'md2man', ['4.0.0']
  s.add_development_dependency 'pry', ['~> 0.10']
end
