require 'open-uri'
require 'fileutils'
require 'digest'

require 'octokit'
require 'ruby-progressbar'

require 'linecook/crypt'

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

    def upload(path)
      puts "Encrypting and uploading image #{path}"
      S3Manager.upload(Linecook::Crypto.new.encrypt_file(path))
    end

    def url(image)
      S3Manager.url("builds/#{image}")
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
        client
        s3 = Aws::S3::Resource.new
        obj = s3.bucket(Linecook::Config.secrets['bucket']).object(name)
        obj.presigned_url(:get, expires_in: EXPIRY * 60)
      end

      def upload(path)
        File.open(path, 'rb') do |file|
          fname = File.basename(path)
          pbar = ProgressBar.create(title: fname, total: file.size)
          common_opts = { bucket: Linecook::Config.secrets['bucket'], key: File.join('builds', fname) }
          resp = client.create_multipart_upload(storage_class: 'REDUCED_REDUNDANCY', server_side_encryption: 'AES256', **common_opts)
          id = resp.upload_id
          part = 0
          total = 0
          parts = []
          while content = file.read(1048576 * 20)
            part += 1
            resp = client.upload_part(body: content, content_length: content.length, part_number: part, upload_id: id, **common_opts)
            parts << { etag: resp.etag, part_number: part }
            total += content.length
            pbar.progress = total
            pbar.title = "#{fname} - (#{((total.to_f/file.size.to_f)*100.0).round(2)}%)"
          end
          client.complete_multipart_upload(upload_id: id, multipart_upload: { parts: parts }, **common_opts)
        end
      end

    private
      def client
        @client ||= begin
          Aws.config[:credentials] = Aws::Credentials.new(Linecook::Config.secrets['aws_access_key'], Linecook::Config.secrets['aws_secret_key'])
          Aws.config[:region] = 'us-east-1'
          Aws::S3::Client.new
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
