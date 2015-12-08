require 'open-uri'
require 'fileutils'
require 'digest'

require 'octokit'
require 'ruby-progressbar'

module Linecook
  module ImageFetcher
    extend self

    def fetch(name, upgrade:false)
      dir = File.join(Config::LINECOOK_HOME, 'images')
      path = File.join(dir, name)
      download(image(name)[:browser_download_url], path ) unless File.exists?(path) || upgrade
      path
    end

  private

    def client
      @client ||= Octokit::Client.new
    end

    def source
      @source ||= (Config.load_config['source_repo'] || 'dalehamel/lxb')
    end

    def latest
      client.releases(source).sort_by{ |r| r[:published_at] }.last
    end

    def image(name)
      latest[:assets].find{ |a| a[:name] =~ /#{name}/ }
    end

    def download(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w") do |f|
        pbar = ProgressBar.create(title: fname, total: nil)
        IO.copy_stream(open(url,
          content_length_proc: lambda {|t|
            if t && 0 < t
              pbar.total = t
            end
          },
          progress_proc: lambda {|s|
            pbar.progress = s
          }), f)
      end
    end

  end
end
