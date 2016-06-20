require 'fileutils'
require 'tmpdir'

require 'linecook-gem/image/s3'
require 'linecook-gem/image/crypt'
require 'linecook-gem/util/downloader'

module Linecook
  class Image

    include Downloader
    include Crypto

    IMAGE_PATH = File.join(Config::LINECOOK_HOME, 'images').freeze

    attr_reader :path, :id, :name, :group, :tag


    def initialize(name, group, tag)
      @name = name
      @group = group ? "#{name}-#{group.gsub(/-|\//,'_')}" : name
      @tag = tag
      @id = if @tag == 'latest'
        id = File.basename(latest).split('.')[0]
        @tag = id.split('-').last
        id
      elsif tag
        "#{@group}-#{@tag}"
      else
        @group
      end
      @path = image_path
    end

    def fetch
      return if File.exists?(@path)

      Dir.mktmpdir("#{@id}-download") do |tmpdir|
        tmppath = File.join(tmpdir, File.basename(@path))
        download(url, tmppath)
        FileUtils.mkdir_p(File.dirname(@path))
        decrypt(tmppath, dest: @path)
        FileUtils.rm_f(tmppath)
      end

    end

    def upload
      puts "Encrypting and uploading image #{@path}"
      encrypted = encrypt(@path)
      provider.upload(encrypted, group: @group)
      FileUtils.rm_f(encrypted)
    end

    def url
      provider.url(@id, group: @group)
    end

    def list
      provider.list(group: @group)
    end

    def latest
      provider.latest(@group)
    end

    #def snapshot(source_path)
    #  FileUtils.mkdir_p(File.dirname(@path))
      #system("sudo mksquashfs #{source_path} #{@path} -noappend -wildcards -e 'dev/*' 'sys/*' 'proc/*' 'run/*' 'tmp/*' 'home/kitchen' 'etc/sudoers.d/kitchen' '.docker*' 'usr/src' 'var/lib/apt/lists/archive*' 'var/cache/apt/archives'") # FIXME make these excludes dynamic based on OS

    #end

  private

    def image_path
      File.join([IMAGE_PATH, @group, "#{@id}.tar.xz"].compact)
    end

    def provider
      S3Manager
    end
  end
end
