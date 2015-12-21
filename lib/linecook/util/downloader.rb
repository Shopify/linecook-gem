require 'open-uri'
require 'fileutils'

require 'zip'
require 'ruby-progressbar'

require 'linecook/image/crypt'

module Linecook
  module Downloader
    LOCK_WAIT_TIMEOUT = 120

    def self.download(url, path, encrypted: false)
      acquire_lock(path)
      FileUtils.mkdir_p(File.dirname(path))
      cryptfile = "#{File.basename(path)}-encrypted"
      destination = encrypted ? File.join('/tmp', cryptfile) : path
      File.open(destination, 'w') do |f|
        pbar = ProgressBar.create(title: File.basename(path), total: nil)
        IO.copy_stream(open(url,
                            content_length_proc: lambda do|t|
                              pbar.total = t if t && 0 < t
                            end,
                            progress_proc: lambda do|s|
                              pbar.progress = s
                            end), f)
      end

      if encrypted
        Linecook::Crypto.new.decrypt_file(destination, dest: path)
        FileUtils.rm_f(destination)
      end
    ensure
      unlock(path)
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

  private

    def self.acquire_lock(path)
      attempts = 0
      while attempts < LOCK_WAIT_TIMEOUT
        return lock(path) unless locked?(path)
        attempts += 1
        sleep(1)
      end
    end

    def self.locked?(path)
      File.exists?(lockfile(path)) && (true if Process.kill(0, File.read(lockfile(path))) rescue false)
    end

    def self.lock(path)
      File.write(lockfile(path), Process.pid.to_s)
    end

    def self.unlock(path)
      FileUtils.rm_f(lockfile(path))
    end

    def self.lockfile(path)
      "/tmp/#{File.basename(path)}-flock"
    end
  end
end
