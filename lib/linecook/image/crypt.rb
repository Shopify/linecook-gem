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
      capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -K #{@secret_key} -iv #{@iv}")
      dest
    end

    def decrypt_file(source, dest: nil, keypath: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -K #{@secret_key} -iv #{@iv} -d")
      dest
    end

    def self.keygen
      iv = OpenSSL::Cipher::Cipher.new(CIPHER).random_iv.unpack('H*').first
      secret_key = Base64.encode64(OpenSSL::Random.random_bytes(KEY_BYTES)).unpack('H*').first
      "[:IV:#{iv}:KY:#{secret_key}]"
    end

  private

    def load_key
      @iv, @secret_key = Linecook.config[:aeskey].match(/\[:IV:(.+):KY:(.+)\]/m).captures
    end
  end
end
