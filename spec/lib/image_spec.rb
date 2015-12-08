require File.expand_path('../../spec_helper.rb', __FILE__)

RSpec.describe Linecook::ImageFetcher do
  let (:checksums) {
    {
      live_iso: 'c0fc5f22d2ce06065e9359823690173878c2b3bd70a0e8bbdffcf55b7430ab82',
      live_image: '946f74d5f5321f06c392f807def8d1999011e0ec5b9b5163caef3d57a90b3eb5',
      base_image: 'e432289d49cb46774e5b7a96dee87d8fce9fefca2c61c029dd7964033e4d2acf'
    }
  }

  it 'can fetch images from github' do
    Linecook::Config.load_config[:images].each do |name, image|
      path = Linecook::ImageFetcher.fetch(image)
      expect(Digest::SHA256.file(path).hexdigest).to eq(checksums[name])
    end
  end
end
