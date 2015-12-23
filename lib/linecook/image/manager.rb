require 'fileutils'

require 'linecook/image/s3'
require 'linecook/image/github'
require 'linecook/image/crypt'

module Linecook
  module ImageManager
    IMAGE_PATH = File.join(Config::LINECOOK_HOME, 'images').freeze
    extend self

    def fetch(image, upgrade:false, profile: :private, type: nil, encrypted: false)
      url_path = if image.is_a?(Symbol)
        image_name = Linecook.config[:image][:images][image][:name]
        path = File.join(IMAGE_PATH, image_name)
        provider(profile).url(image_name) unless File.exist?(path) || upgrade
      elsif image.is_a?(Hash)
        profile = :private
        encrypted = true
        name = image[:name] == :latest ? File.basename(latest(image[:type])) : image[:name]
        path = File.join([IMAGE_PATH, image[:type], name].compact)
        provider(profile).url(name, type: image[:type])
      else
        puts "#{image} is invalid"
      end

      Linecook::Downloader.download(url_path, path, encrypted: encrypted) unless File.exist?(path) || upgrade
      path
    end

    def clean(type: nil)
      Dir["#{File.join([IMAGE_PATH, type].compact)}/**/*"].each do |image|
        FileUtils.rm_f(image) unless `mount`.index(image)
      end
    end

    def upload(image, profile: :private, type: nil)
      path = File.join(IMAGE_PATH, File.basename(image))
      puts "Encrypting and uploading image #{path}"
      encrypted = Linecook::Crypto.new.encrypt_file(path)
      provider(profile).upload(encrypted, type: type)
      FileUtils.rm_f(encrypted)
    end

    def url(image, profile: :private, type: nil)
      provider(profile).url(image, type: type)
    end

    def list(type: nil, profile: :private)
      profile = profile.to_sym
      provider(profile).list(type: type)
    end

    def latest(type, profile: :private)
      profile = profile.to_sym
      provider(profile).latest(type)
    end

  private

    def provider(image_profile)
      profile = Linecook.config[:image][:provider][image_profile]
      case profile
      when :s3
        S3Manager
      when :github
        GithubManager
      else
        fail "No provider implemented for for #{profile}"
      end
    end
  end
end
