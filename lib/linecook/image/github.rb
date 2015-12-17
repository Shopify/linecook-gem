require 'octokit'

require 'linecook/util/config'

module Linecook
  module GithubManager
    extend self

    def url(name)
      latest[:assets].find { |a| a[:name] =~ /#{name}/ }[:browser_download_url]
    end

  private

    def client
      @client ||= Octokit::Client.new
    end

    def source
      @source ||= (Linecook.config['source_repo'] || 'dalehamel/lxb')
    end

    def latest
      client.releases(source).sort_by { |r| r[:published_at] }.last
    end
  end
end
