require 'md2man/roff/engine'

MANPAGE_PATH = File.expand_path('../man/LINECOOK.1', __FILE__)

desc 'Generate manpage'
task :man_generate do
  input = File.read(File.expand_path('../README.md', __FILE__))
  File.write(MANPAGE_PATH, Md2Man::Roff::ENGINE.render(input))
end

desc 'Show the manpage'
task man: [:man_generate] do
  system("man #{MANPAGE_PATH}")
end

desc 'Build the ruby gem'
task build: [:man_generate] do
  system('gem build linecook.gemspec') || fail('Failed to build gem')
end

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task default: :spec
rescue LoadError
  puts 'no rspec available'
end
