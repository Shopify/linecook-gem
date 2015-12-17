require 'open-uri'
require 'fileutils'

require 'zip'
require 'ruby-progressbar'

module Linecook
  module Downloader
    def self.download(url, path)
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

    def self.unzip(source, dest: nil)
      puts "Extracting #{source}..."
      dest ||= File.dirname(source)
      Zip::File.open(source) do |zip_file|
        zip_file.each do |f|
          file_path = File.join(dest, f.name)
          FileUtils.mkdir_p(File.dirname(file_path))
          zip_file.extract(f, file_path)
        end
      end
    end
  end
end
