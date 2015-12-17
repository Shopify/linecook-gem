require 'open-uri'
require 'fileutils'

require 'ruby-progressbar'
require 'linecook/image/crypt'
require 'linecook/image/github'
require 'linecook/image/s3'

module Linecook
  module ImageManager
    IMAGE_PATH = File.join(Config::LINECOOK_HOME, 'images').freeze
    extend self

    def fetch(name, upgrade:false, profile: :private)
      image_name = Linecook::Config.load_config[:image][:images][name][:name]
      path = File.join(IMAGE_PATH, image_name)
      url = provider(profile).url(name) unless File.exist?(path) || upgrade# FIXME
      download(url, path) unless File.exist?(path) || upgrade
      path
    end

    def upload(image, profile: :private)
      path = File.join(IMAGE_PATH, File.basename(image))
      puts "Encrypting and uploading image #{path}"
      provider(profile).upload(Linecook::Crypto.new.encrypt_file(path))
    end

    def url(image, profile: :private)
      provider(profile).url("builds/#{image}")
    end

  private

    def provider(image_profile)
      profile = Linecook::Config.load_config[:image][:provider][image_profile]
      case profile
      when :s3
        S3Manager
      when :github
        GithubManager
      else
        fail "No provider implemented for for #{profile}"
      end
    end

    def download(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |f|
        pbar = ProgressBar.create(title: File.basename(path), total: nil)
        IO.copy_stream(open(url,
                            content_length_proc: lambda do|t|
                              pbar.total = t if t && 0 < t
                            end,
                            progress_proc: lambda do|s|
                              pbar.progress = s
                            end), f)
      end
    end
  end
end
