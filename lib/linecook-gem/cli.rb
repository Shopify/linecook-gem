require 'thor'
require 'linecook-gem'

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
  method_option :type, type: :string, required: false, banner: 'ID', desc: 'Type of image to list', aliases: '-t'
  method_option :profile, type: :string, default: 'private', banner: 'PROFILE', desc: 'Profile (public/private) of image to list', enum: %w(public private), aliases: '-p'
  def list
    opts = options.symbolize_keys
    puts Linecook::ImageManager.list(**opts)
  end

  desc 'latest ID', 'Get the latest image by id' # add remote flag
  method_option :profile, type: :string, default: 'private', banner: 'PROFILE', desc: 'Profile (public/private) of image to list', enum: %w(public private), aliases: '-p'
  def latest(id)
    opts = options.symbolize_keys
    puts Linecook::ImageManager.latest(id, **opts)
  end

  desc 'fetch', 'Fetch and decrypt an image'
  method_option :type, type: :string, required: false, banner: 'ID', desc: 'Type of image to list', aliases: '-t'
  method_option :latest, type: :boolean, default: false, desc: 'Use the latest build for type', aliases: '-l'
  method_option :name, type: :string, required: false, banner: 'NAME', desc: 'Name of the image to snapshot. Specify this, or --latest with a type', aliases: '-n'
  def fetch
    fail 'Must specify image name or use latest' unless options[:name] || options[:latest]
    fail 'Must specify type if specifying latest' if options[:latest] && !options[:type]

    image = options[:latest] ? { type: options[:type], name: :latest } : options[:name].to_sym
    Linecook::ImageManager.fetch(image)
  end

  desc 'clean', 'Clean up cached images'
  method_option :type, type: :string, required: true, banner: 'ID', desc: 'Type of image to list', aliases: '-t'
  def clean
    opts = options.symbolize_keys
    puts Linecook::ImageManager.clean(**opts)
  end

  desc 'upload IMAGE', 'Upload an image'
  method_options name: :string
  def upload(image)
    Linecook::ImageManager.upload(image)
  end

  desc 'url IMAGE', 'Get URL for image'
  method_option :type, type: :string, required: false, banner: 'ID', desc: 'Type of image to list', aliases: '-t'
  def url(image)
    opts = options.symbolize_keys
    puts Linecook::ImageManager.url(image, **opts)
  end

  desc 'package', 'Package image'
  method_option :name, type: :string, required: false, banner: 'NAME', desc: 'Name of the image to snapshot. Specify this, or --latest with a type', aliases: '-n'
  method_option :latest, type: :boolean, default: false, desc: 'Use the latest build for type', aliases: '-l'
  method_option :ami, type: :boolean, default: true, desc: 'Create an ami', aliases: '-a'
  method_option :type, type: :string, required: false, banner: 'ID', desc: 'Type of image to snapshot', aliases: '-t'
  def package
    fail 'Must specify image name or use latest' unless options[:name] || options[:latest]
    fail 'Must specify type if specifying latest' if options[:latest] && !options[:type]
    name = options[:latest] ? Linecook::ImageManager.latest(options[:type]) : options[:name]
    Linecook::Packager.package(name, type: options[:type], ami: options[:ami])
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
  method_option :resume, type: :boolean, default: false,  desc: 'Resume the build after snapshotting it', aliases: '-r'
  def snapshot
    build = Linecook::Build.new(name, '')
    build.snapshot(save: true)
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
  method_option :tag, type: :string, required: false, banner: 'TAG', desc: 'Optional tag for a build', aliases: '-t'
  method_option :id, type: :string, required: false, banner: 'ID', desc: 'Optional id for a build', aliases: '-i'
  method_option :keep, type: :boolean, default: true, desc: 'Keep the build running when done', aliases: '-k'
  method_option :clean, type: :boolean, default: false, desc: 'Clean up all build artifacts', aliases: '-c'
  method_option :build, type: :boolean, default: true, desc: 'Build the image', aliases: '-b'
  method_option :snapshot, type: :boolean, default: false, desc: 'Snapshot the resulting build to create an image', aliases: '-s'
  method_option :upload, type: :boolean, default: false, desc: 'Upload the resulting build. Implies --snapshot and --encrypt.', aliases: '-u'
  method_option :package, type: :boolean, default: false, desc: 'Package the resulting image. Implies --upload, --snapshot and --encrypt.', aliases: '-p'
  def bake
    opts = options.symbolize_keys
    Linecook::Baker.bake(**opts)
  end
end
