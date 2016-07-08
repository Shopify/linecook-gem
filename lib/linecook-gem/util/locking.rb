require 'fileutils'

module Linecook
  module Locking
    def lock(name)
      lockfile(name).flock(File::LOCK_EX)
    end

    def unlock(name)
      return unless File.exists?(lock_path(name))
      lockfile(name).flock(File::LOCK_UN)
      lockfile(name).close
    rescue IOError => e
      puts e.message
    end

    def clear_lock(name)
      unlock(name)
      FileUtils.rm_f(lockfile(name))
    end

    def lockfile(suffix)
      @locks ||= {}
      path = lock_path(suffix)
      @locks[path] = @locks[path] || File.open(path, File::RDWR|File::CREAT, 0644)
    end

    def lock_path(suffix)
      "/tmp/lock_#{suffix.gsub('/','_')}"
    end
  end
end
