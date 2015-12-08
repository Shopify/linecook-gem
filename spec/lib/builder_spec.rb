require File.expand_path('../../spec_helper.rb', __FILE__)

RSpec.describe Linecook::Builder do

  context 'linux_backend' do
    it 'gets a backend' do
      expect(Linecook::Builder.backend).to_not be_nil
    end

    it 'can start a backend' do
      expect(Linecook::Builder.running?).to eq(false)
      Linecook::Builder.start
      expect(Linecook::Builder.running?).to eq(true)
      Linecook::Builder.stop
    end

    it 'can get the ip' do
      Linecook::Builder.start
      expect(Linecook::Builder.ip).to_not be_nil
      Linecook::Builder.stop
    end
  end
end
