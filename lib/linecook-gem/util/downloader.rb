require 'open-uri'
require 'fileutils'
require 'securerandom'

require 'zip'
require 'ruby-progressbar'

module Linecook
  module Downloader
    LOCK_WAIT_TIMEOUT = 180

    def download(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      cryptfile = "#{File.basename(path)}-encrypted-#{SecureRandom.hex(4)}"
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

    def unzip(source, dest: nil)
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
