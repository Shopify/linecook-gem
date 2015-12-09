require 'thor'
require 'linecook'

class Builder < Thor

  desc 'info', 'Show builder info'
  def info
    puts Linecook::Builder.info
  end

  desc 'start', 'Start the builder'
  def start
    Linecook::Builder.start
  end

  desc 'stop', 'Stop the builder'
  def stop
    Linecook::Builder.stop
  end

  desc 'ip', 'Show the external ip address of the builder'
  def ip
    puts Linecook::Builder.ip
  end
end

class Build < Thor

  desc 'list', 'Show all builds'
  def list
    puts Linecook::Builder.builds
  end

  desc 'info', 'Show build info' # FIXME accept the build name
  def info
    puts Linecook::Builder.build_info
  end
end

class Linecook::CLI < Thor

  desc 'builder SUBCOMMAND', 'Manage builders'
  subcommand 'builder', Builder

  desc 'build SUBCOMMAND', 'Manage builds'
  subcommand 'build', Build

  desc 'bake', 'Bake a new image'
  def bake
    Linecook::Baker.bake
  end

  desc 'fetch IMAGE_NAME', 'Fetch an image by name'
  method_options name: :string
  def fetch(name)
    Linecook::ImageFetcher.fetch(name)
  end

end
