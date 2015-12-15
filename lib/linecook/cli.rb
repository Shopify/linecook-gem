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

  desc 'info', 'Show build info' # FIXME: accept the build name
  def info
    puts Linecook::Builder.build_info
  end

  desc 'snapshot NAME', 'Take a snapshot of the build with NAME'
  method_options name: :string
  def snapshot(name)
    build = Linecook::Build.new(name, '')
    build.snapshot(download: true)
  end

  desc 'upload PATH', ''
  method_options name: :string
  def upload(path)
    Linecook::ImageManager.upload(path)
  end

  desc 'url IMAGE', ''
  method_options image: :string
  def url(image)
    puts Linecook::ImageManager.url(image)
  end

  desc 'install PATH', 'Install a snapshot at PATH'
  method_options path: :string
  def install(path)
    installer = Linecook::EBSInstaller.new(path)
    installer.install
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

  desc 'keygen', 'Generate AES key for securing images'
  def keygen
    puts Linecook::Crypto.keygen
  end

  desc 'decrypt PATH', ''
  def decrypt(path)
    puts Linecook::Crypto.new.decrypt_file(path)
  end

  desc 'encrypt PATH', ''
  def encrypt(path)
    puts Linecook::Crypto.new.encrypt_file(path)
  end


  desc 'fetch IMAGE_NAME', 'Fetch an image by name'
  method_options name: :string
  def fetch(name)
    Linecook::ImageManager.fetch(name)
  end
end
