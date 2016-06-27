require 'mkmf'
require 'fileutils'
require 'tmpdir'

require 'linecook-gem/image'

module Linecook
  class Squashfs

    EXCLUDE_PROFILES = {
      common: [
        'dev/*',
        'sys/*',
        'proc/*',
        'run/*',
        'tmp/*',
        'home/kitchen',
        'etc/sudoers.d/kitchen',
        '.docker*',
      ],
      ubuntu: [
        'usr/src',
        'var/lib/apt/lists/archive*',
        'var/cache/apt/archives*'
      ]
    }.freeze

    def initialize(config)
      @excludes = []
      @excludes << EXCLUDE_PROFILES[:common]
      @excludes << EXCLUDE_PROFILES[config[:distro]] if config[:distro]
      @excludes << config[:excludes] if config[:excludes]
      @excludes.flatten!
      @outdir = config[:outdir] || Dir.pwd
    end

    def package(image)
      FileUtils.mkdir_p(@outdir)
      tmpdir = Dir.mktmpdir("#{image.id}-squashfs")
      outfile = File.join(@outdir, "#{image.id}.squashfs")
      puts "Extracting #{image.id} to temporary directory #{tmpdir}..."
      system("sudo tar -C #{tmpdir} -xpf #{image.path}")
      system("sudo mksquashfs #{tmpdir} #{outfile} -noappend -wildcards -e #{@excludes.map { |e| "'#{e}'" }.join(' ')}")
      puts "Squashed image is at #{outfile}"
    ensure
      puts "Cleaning up #{tmpdir}..."
      system("sudo rm -rf #{tmpdir}")
    end

  end
end
