require 'rbnacl/libsodium'

module Linecook
  module Crypto

    def self.keygen
       RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes).unpack('H*').first
    end

    def encrypt(source, dest: nil)
      dest ||= "/tmp/#{File.basename(source)}"
      File.write(dest, box.encrypt(IO.binread(source)))
      dest
    end

    def decrypt(source, dest: nil)
      dest ||= "/tmp/#{File.basename(source)}-decrypted"
      File.write(dest, box.decrypt(IO.binread(source)))
      dest
    end

  private
    def box
      @box ||= RbNaCl::SimpleBox.from_secret_key([Linecook.config[:imagekey]].pack('H*'))
    end
  end
end
