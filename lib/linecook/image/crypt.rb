require 'base64'
require 'encryptor'

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

    def encrypt_file(source, dest: nil, keypath: nil)
      dest ||= "/tmp/#{File.basename(source)}"
      capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -pass 'pass:#{@secret_key}'", sudo: false)
      dest
    end

    def decrypt_file(source, dest: nil, keypath: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -pass pass:#{@secret_key}' -d", sudo: false)
      dest
    end

    def self.keygen
      secret_key = Base64.encode64(OpenSSL::Random.random_bytes(KEY_BYTES)).unpack('H*').first
    end

  private

    def load_key
      @secret_key = Linecook.config[:aeskey]
    end
  end
end
