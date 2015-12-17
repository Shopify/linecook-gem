lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'linecook/version'

Gem::Specification.new do |s|
  s.name        = 'linecook-gem'
  s.version     = Linecook::VERSION
  s.date        = '2015-11-24'
  s.summary     = 'Build system images using chef zero, LXC, and packer'
  s.description = 'Build and snapshot a system image for distribution, CI, or both using real chef cookbooks and a fake server.'
  s.authors     = ['Dale Hamel']
  s.email       = 'dale.hamel@srvthe.net'
  s.files       = Dir['lib/**/*'] + Dir['man/**/*']
  s.executables = 'linecook'
  s.homepage    =
    'http://rubygems.org/gems/linecook'
  s.license = 'MIT'
  s.add_runtime_dependency 'xhyve-ruby', ['=0.0.5']
  s.add_runtime_dependency 'sshkit', ['=1.7.1']
  s.add_runtime_dependency 'sshkey', ['=1.8.0']
  s.add_runtime_dependency 'octokit', ['=4.2.0']
  s.add_runtime_dependency 'chefdepartie', ['=0.0.7']
  s.add_runtime_dependency 'chef-provisioner', ['=0.1.2']
  s.add_runtime_dependency 'activesupport', ['=4.2.5']
  s.add_runtime_dependency 'ruby-progressbar', ['=1.7.5']
  s.add_runtime_dependency 'ipaddress', ['=0.8.0']
  s.add_runtime_dependency 'encryptor', ['=1.3.0']
  s.add_runtime_dependency 'ejson',  ['1.0.1']
  s.add_runtime_dependency 'aws-sdk',  ['2.2.4']
  s.add_runtime_dependency 'rubyzip',  ['1.1.7']
  s.add_development_dependency 'rake', ['=10.4.2']
  s.add_development_dependency 'simplecov', ['=0.10.0']
  s.add_development_dependency 'rspec', ['=3.2.0']
  s.add_development_dependency 'md2man', ['4.0.0']
end
