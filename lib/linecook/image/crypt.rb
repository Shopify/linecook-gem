require 'tempfile'

require 'rbnacl/libsodium'

require 'linecook/image/manager'
require 'linecook/util/executor'
require 'linecook/util/config'

module Linecook
  class Crypto
    include Executor

    def initialize(remote: nil)
      @remote = remote
      load_key
    end

    def encrypt_image(image)
      image_path = File.join(Linecook::ImageManager::IMAGE_PATH,File.basename(image))
      encrypt_file(image_path)
    end

    def encrypt_file(source, dest: nil)
      dest ||= "/tmp/#{File.basename(source)}"
      File.write(dest, box.encrypt(IO.binread(source)))
      dest
    end

    def decrypt_file(source, dest: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      if @remote
        Tempfile.open('key') do |key|
          @remote.upload(decryptor_script(source, dest), key.path)
          @remote.run("bash #{key.path}")
          @remote.run("rm #{key.path}")
        end
      else
        File.write(dest, box.decrypt(IO.binread(source)))
      end
      dest
    end

    def self.keygen
       RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes).unpack('H*').first
    end

  private

    def decryptor_script(source, dest)
      "ruby -e \"require 'rbnacl/libsodium'; box = RbNaCl::SimpleBox.from_secret_key(['#{@secret_key}'].pack('H*')); File.write('#{dest}', box.decrypt(File.read('#{source}')))\""
    end

    def box
      @box ||= RbNaCl::SimpleBox.from_secret_key([@secret_key].pack('H*'))
    end

    def load_key
      @secret_key = Linecook.config[:imagekey]
    end
  end
end
