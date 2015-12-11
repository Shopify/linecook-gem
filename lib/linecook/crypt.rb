require 'base64'
require 'encryptor'

module Linecook
  module Crypto
    extend self

    def encrypt_file(source, dest, keypath: nil)
      load_key(File.read(keypath)) if keypath
      File.write(dest, Encryptor.encrypt(File.read(source), key: @secret_key, iv: @iv, salt: @salt))
    end

    def decrypt_file(source, dest, keypath: nil)
      load_key(File.read(keypath)) if keypath
      File.write(dest, Encryptor.decrypt(File.read(source), key: @secret_key, iv: @iv, salt: @salt))
    end

    def keygen
      key_init
      "[:IV:#{Base64.encode64(@iv)}:ST:#{@salt}:KY:#{@secret_key}]"
    end

    def load_key(data)
      iv, @salt, @secret_key = data.match(/\[:IV:(.+):ST:(.+):KY:(.+)\]/m).captures
      @iv = Base64.decode64(iv)
    end

  private
    def key_init
      @iv ||= OpenSSL::Cipher::Cipher.new('aes-256-gcm').random_iv
      @salt ||= SecureRandom.uuid
      @secret_key ||= Base64.encode64(OpenSSL::Random.random_bytes(32))
    end
  end
end
