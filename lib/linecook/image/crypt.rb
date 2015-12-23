require 'tempfile'

require 'rbnacl/libsodium'
require 'rbnacl'

require 'linecook/image/manager'
require 'linecook/util/executor'
require 'linecook/util/config'

module Linecook
  class Crypto
    include Executor
    CIPHER = 'aes-256-cbc'
    KEY_BYTES = 32 # 256 bits
    attr_reader :iv, :secret_key

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
      File.write(dest, box.encrypt(File.read(source)))
      dest
    end

    def decrypt_file(source, dest: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      if @remote
        Tempfile.open('key') do |key|
          @remote.upload(@secret_key, key.path) 
          capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -kfile #{key.path} -d", sudo: false)
          @remote.run("rm #{key.path}") if @remote
        end
      else
        File.write(dest, box.decrypt(File.read(source)))
      end
      dest
    end

    def self.keygen
       RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes).unpack('H*').first
    end

  private

# sudo apt-get install -y -force-yes build-essential ruby ruby-dev
# sudo gem install rbnacl nbnacl-libsodium

#ruby -e 'require "base64"; require "rbnacl/libsodium"; box = RbNaCl::SimpleBox.from_secret_key(["c1b44affe71692bc8a09920932be5270d699a282a5386a3534855275938e1d62"].pack("H*")); puts Base64.encode64(box.encrypt("hi"))'

    def self.decryptor_script
#ruby -e 'require "rbnacl/libsodium"; box = RbNaCl::SimpleBox.from_secret_key(["c1b44affe71692bc8a09920932be5270d699a282a5386a3534855275938e1d62"].pack("H*")); box.encrypt("hi")'
    end

    def self.box
      @box ||= RbNaCl::SimpleBox.from_secret_key([@secret_key].pack('H*'))
    end

    def load_key
      @secret_key = Linecook.config[:aeskey]
    end
  end
end
