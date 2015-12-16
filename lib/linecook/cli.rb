require 'thor'
require 'linecook'

class Crypto < Thor
  desc 'keygen', 'Generate AES key for securing images'
  def keygen
    puts Linecook::Crypto.keygen
  end

  desc 'decrypt IMAGE', ''
  def decrypt(image)
    puts Linecook::Crypto.new.decrypt_file(image)
  end

  desc 'encrypt IMAGE', ''
  def encrypt(image)
    puts Linecook::Crypto.new.encrypt_file(image)
  end
end

class Image < Thor
  desc 'crypto SUBCOMMAND', 'Manage image encryption'
  subcommand 'crypto', Crypto

  desc 'list', 'List images' # add remote flag
  def list
  end

  desc 'fetch IMAGE_NAME', 'Fetch an image by name'
  method_options name: :string
  def fetch(name)
    Linecook::ImageManager.fetch(name)
  end

  desc 'upload IMAGE', 'Upload an image'
  method_options name: :string
  def upload(image)
    Linecook::ImageManager.upload(image)
  end

  desc 'url IMAGE', 'Get URL for image'
  method_options image: :string
  def url(image)
    puts Linecook::ImageManager.url(image)
  end

  desc 'package IMAGE', 'Package image'
  method_options image: :string
  def install(image)
    packager = Linecook::EBSPackager.new(image)
    packager.package
  end
end

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

  desc 'info', 'Show build info'
  def info
  end

  desc 'ip', 'Show IP address for build'
  def ip
  end

  desc 'snapshot', 'Take a snapshot of the build with NAME'
  method_option :name, type: :string, required: true, banner: 'ROLE_NAME', desc: 'Name of the role to build', aliases: '-n'
  def snapshot
    build = Linecook::Build.new(name, '')
    build.snapshot(download: true)
  end
end

class Linecook::CLI < Thor

  desc 'image SUBCOMMAND', 'Manage linecook images.'
  subcommand 'image', Image

  desc 'builder SUBCOMMAND', 'Manage the builder.'
  subcommand 'builder', Builder

  desc 'build SUBCOMMAND', 'Manage running and completed builds.'
  subcommand 'build', Build

  desc 'bake', 'Bake a new image.'
  method_option :name, type: :string, required: true, banner: 'ROLE_NAME', desc: 'Name of the role to build', aliases: '-n'
  method_option :image, type: :string,  banner: 'SOURCE_IMAGE', desc: 'Source image to seed the build.', aliases: '-i'
  method_option :snapshot, type: :boolean, default: false, desc: 'Snapshot the resulting build to create an image', aliases: '-s'
  method_option :encrypt, type: :boolean, default: false, desc: 'Encrypt the resulting build. Implies --snapshot.', aliases: '-e'
  method_option :upload, type: :boolean, default: false, desc: 'Upload the resulting build. Implies --snapshot and --encrypt.', aliases: '-u'
  def bake
    puts options
    #Linecook::Baker.bake
  end
end
