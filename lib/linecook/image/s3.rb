require 'ruby-progressbar'
require 'aws-sdk'

module Linecook
  module S3Manager
    extend self
    EXPIRY = 20
    PREFIX = 'builds'

    def url(name, type: nil)
      client
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(Linecook.config[:aws][:s3][:bucket]).object(File.join([PREFIX, type, name].compact))
      obj.presigned_url(:get, expires_in: EXPIRY * 60)
    end

    def list(type: nil)
      list_objects(type: type).map{ |x| x.key if x.key =~ /squashfs$/ }.compact
    end

    def latest(type)
      objects = list_objects(type: type).sort! { |a,b| a.last_modified <=> b.last_modified }
      key = objects.last ? objects.last.key : nil
    end

    def upload(path, type: nil)
      File.open(path, 'rb') do |file|
        fname = File.basename(path)
        pbar = ProgressBar.create(title: fname, total: file.size)
        common_opts = { bucket: Linecook.config[:aws][:s3][:bucket], key: File.join([PREFIX, type, fname].compact) }
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

    def list_objects(type: nil)
      client.list_objects(bucket: Linecook.config[:aws][:s3][:bucket], prefix: File.join([PREFIX, type].compact)).contents
    end

    def client
      @client ||= begin
        Aws.config[:credentials] = Aws::Credentials.new(Linecook.config[:aws][:access_key], Linecook.config[:aws][:secret_key])
        Aws.config[:region] = 'us-east-1'
        Aws::S3::Client.new
      end
    end
  end
end
