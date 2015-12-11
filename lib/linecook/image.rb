require 'open-uri'
require 'fileutils'
require 'digest'

require 'octokit'
require 'ruby-progressbar'

module Linecook
  module ImageManager
    IMAGE_PATH = File.join(Config::LINECOOK_HOME, 'images').freeze
    extend self

    def fetch(name, upgrade:false)
      path = File.join(IMAGE_PATH, name)
      url = GithubFetcher.url(name) unless File.exist?(path) || upgrade# FIXME
      download(url, path) unless File.exist?(path) || upgrade
      path
    end

  private

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

    module S3Manager
      extend self
      EXPIRY = 20

      def url(name)
        object = @client.buckets[@secrets[:bucket]].objects[name]
        object.url_for(:get, { expires: EXPIRY.minutes.from_now, secure: true }).to_s
      end

      def upload(path)
        File.open(path, 'rb') do |file|
          @client.put_object(bucket: @secrets[:bucket], key: File.basename(name), body: file, storage_class: 'REDUCED_REDUNDANCY', server_side_encryption: 'AES256')
        end
      end

    private
      def client
        @client ||= begin
          @secrets ||= Linecook::Config.load_secrets[:s3]
          credentials = Aws::Credentials.new(@secrets['aws_access_key_id'], @secrets['aws_secret_access_key'])
          Aws::S3::Client.new(region: 'us-east-1', credentials: credentials)
        end
      end
    end

    module GithubFetcher
      extend self

      def url(name)
        latest[:assets].find { |a| a[:name] =~ /#{name}/ }[:browser_download_url]
      end

    private

      def client
        @client ||= Octokit::Client.new
      end

      def source
        @source ||= (Config.load_config['source_repo'] || 'dalehamel/lxb')
      end

      def latest
        client.releases(source).sort_by { |r| r[:published_at] }.last
      end
    end
  end
end
