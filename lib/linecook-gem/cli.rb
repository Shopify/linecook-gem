require 'thor'
require 'linecook-gem'

class Image < Thor

  desc 'keygen', 'Generate a new encryption key'
  def keygen
    puts Linecook::Crypto.keygen
  end


  desc 'list', 'List images'
  method_option :name, type: :string, required: false, banner: 'NAME', desc: 'Name of the image to fetch.', aliases: '-n'
  method_option :group, type: :string, required: false, banner: 'ID', desc: 'Group of image to list', aliases: '-g'
  def list
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], nil)
    puts image.list
  end

  desc 'clean', 'Cleanup old images'
  method_option :name, type: :string, required: true, banner: 'NAME', desc: 'Name of the image to fetch.', aliases: '-n'
  method_option :group, type: :string, required: true, banner: 'ID', desc: 'Group of image to list', aliases: '-g'
  method_option :retention, type: :numeric, required: false, banner: 'RETENTION', desc: 'Images to keep', aliases: '-k', default: 5
  def clean
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], nil)
    puts "Cleaned up #{image.clean(opts[:retention]).length} images"
  end

  desc 'fetch', 'Fetch and decrypt an image'
  method_option :name, type: :string, required: true, banner: 'NAME', desc: 'Name of the image to fetch.', aliases: '-n'
  method_option :tag, type: :string, default: 'latest', banner: 'NAME', desc: 'Tag of the image to fetch.', aliases: '-t'
  method_option :group, type: :string, required: false, banner: 'ID', desc: 'Group of image to list', aliases: '-g'
  def fetch
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], opts[:tag] )
    image.fetch
  end

  desc 'upload', 'Upload an image'
  method_option :name, type: :string, required: true, banner: 'NAME', desc: 'Name of the image to upload.', aliases: '-n'
  method_option :tag, type: :string, default: 'latest', banner: 'NAME', desc: 'Tag of the image to upload.', aliases: '-t'
  method_option :group, type: :string, required: false, banner: 'ID', desc: 'Group of image to group', aliases: '-g'
  def upload
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], opts[:tag] )
    image.upload
  end

  desc 'package', 'Package image'
  method_option :name, type: :string, required: true, banner: 'NAME', desc: 'Name of the image to package.', aliases: '-n'
  method_option :tag, type: :string, default: 'latest', banner: 'NAME', desc: 'Tag of the image to package.', aliases: '-t'
  method_option :group, type: :string, required: false, banner: 'ID', desc: 'Group of image to package', aliases: '-g'
  method_option :strategy, type: :string, default: 'packer', banner: 'STRATEGY', enum: ['packer', 'squashfs'], desc: 'Packaging strategy', aliases: '-s'
  def package
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], opts[:tag])
    Linecook::Packager.package(image, name: opts[:strategy])
  end

  desc 'save', 'Save running build'
  method_option :name, type: :string, required: true, banner: 'NAME', desc: 'Name of the image to package.', aliases: '-n'
  method_option :tag, type: :string, default: 'latest', banner: 'NAME', desc: 'Tag of the image to package.', aliases: '-t'
  method_option :group, type: :string, required: false, banner: 'ID', desc: 'Group of image to package', aliases: '-g'
  method_option :directory, type: :string, required: false, banner: 'DIR', desc: 'Directory containing kitchen files', aliases: '-d'
  def save
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], opts[:tag])
    baker = Linecook::Baker::Baker.new(image, directory: opts[:directory])
    baker.save
  end

end

class Linecook::CLI < Thor

  desc 'image SUBCOMMAND', 'Manage linecook images.'
  subcommand 'image', Image

  desc 'bake', 'Bake a new image.'
  method_option :name, type: :string, required: true, banner: 'ROLE_NAME', desc: 'Name of the role to build', aliases: '-n'
  method_option :group, type: :string, required: false, banner: 'CLASS', desc: 'Optional class for a build', aliases: '-g'
  method_option :tag, type: :string, required: false, banner: 'TAG', desc: 'Optional tag for a build', aliases: '-t'
  method_option :directory, type: :string, required: false, banner: 'DIR', desc: 'Directory containing kitchen files', aliases: '-d'
  method_option :keep, type: :boolean, default: false, desc: 'Keep the build running when done', aliases: '-k'
  method_option :snapshot, type: :boolean, default: false, desc: 'Snapshot the resulting build to create an image', aliases: '-s'
  method_option :upload, type: :boolean, default: false, desc: 'Upload the resulting build. Implies --snapshot.', aliases: '-u'
  #method_option :package, type: :boolean, default: false, desc: 'Package the resulting image. Implies --upload and --snapshot', aliases: '-p'
  def bake
    opts = options.symbolize_keys
    image = Linecook::Image.new(opts[:name], opts[:group], opts[:tag])
    baker = Linecook::Baker::Baker.new(image, directory: opts[:directory])
    baker.bake(snapshot: opts[:snapshot], upload: opts[:upload], keep: opts[:keep])
  end

  desc 'clean', 'Clean up the kitchen, destroy all builds'
  method_option :directory, type: :string, required: false, banner: 'DIR', desc: 'Directory containing kitchen files', aliases: '-d'
  def clean
    opts = options.symbolize_keys
    image = Linecook::Image.new(nil, nil, nil)
    baker = Linecook::Baker::Baker.new(image, directory: opts[:directory])
    baker.clean_kitchen
  end

  desc 'man', 'Show the manpage'
  def man
    path = File.join(Gem::Specification.find_by_name('linecook-gem').gem_dir, 'man', 'LINECOOK.1' )
    system("man #{path}")
  end

  desc 'version', 'Print the current version'
  def version
    puts Linecook::VERSION
  end

end
