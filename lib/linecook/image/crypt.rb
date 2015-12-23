require 'tempfile'

require 'linecook/image/manager'
require 'linecook/util/executor'
require 'linecook/util/config'

require 'encryptor'
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
      Tempfile.open('key') do |key|
        key.write(@secret_key)
        key.flush
        capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -kfile #{key.path}", sudo: false)
      end
      dest
    end

    def decrypt_file(source, dest: nil, keypath: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      Tempfile.open('key') do |key|
        key.write(@secret_key)
        key.flush
        @remote.upload(@secret_key, key.path) if @remote
        capture("openssl enc -#{CIPHER} -out #{dest} -in #{source} -kfile #{key.path} -d", sudo: false)
        @remote.run("rm #{key.path}") if @remote
      end
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
