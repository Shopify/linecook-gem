require 'ruby-progressbar'
require 'aws-sdk'

module Linecook
  module S3Manager
    extend self
    EXPIRY = 20
    PREFIX = 'built-images'

    def url(id, group: nil)
      client
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(Linecook.config[:aws][:s3][:bucket]).object(File.join([PREFIX, group, "#{id}.tar.xz"].compact))
      obj.presigned_url(:get, expires_in: EXPIRY * 60)
    end

    def list(group: nil)
      list_objects(group: group).map{ |x| x.key if x.key =~ /\.tar\.xz/ }.compact
    end

    def clean(retention, group)
      full_set = list(group: group)
      keep = full_set.reverse.take(retention)
      destroy = full_set - keep
      destroy.each_slice(1000).each do |garbage|
        to_destroy = garbage.map { |x| { key: x } }
        client.delete_objects(bucket: Linecook.config[:aws][:s3][:bucket], delete: { objects: to_destroy} )
      end
      return destroy
    end

    def latest(group)
      objects = list_objects(group: group).sort! { |a,b| a.last_modified <=> b.last_modified }
      key = objects.last ? objects.last.key : nil
    end

    def upload(path, group: nil)
      File.open(path, 'rb') do |file|
        fid = File.basename(path)
        pbar = ProgressBar.create(title: fid, total: file.size)
        common_opts = { bucket: Linecook.config[:aws][:s3][:bucket], key: File.join([PREFIX, group, fid].compact) }
        resp = client.create_multipart_upload(storage_class: 'STANDARD', server_side_encryption: 'AES256', **common_opts)
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
          pbar.title = "#{fid} - (#{((total.to_f/file.size.to_f)*100.0).round(2)}%)"
        end
        client.complete_multipart_upload(upload_id: id, multipart_upload: { parts: parts }, **common_opts)
      end
    end

  private

    def list_objects(group: nil)
      contents = []
      marker = nil
      loop do
        resp = client.list_objects(bucket: Linecook.config[:aws][:s3][:bucket], prefix: File.join([PREFIX, group].compact), marker: marker)
        break unless resp.contents.last
        marker = resp.contents.last.key
        contents += resp.contents
      end
      contents.sort { |a,b| a.last_modified <=> b.last_modified }
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
