require File.expand_path('../../spec_helper.rb', __FILE__)

require 'linecook/cli'

RSpec.describe 'cli' do
  context 'builder' do
    it 'can start and stop a builder' do
      b = Builder.new
      b.start
      expect{b.info}.to output(/RUNNING/).to_stdout
      b.stop
      expect{b.info}.to output(/STOPPED/).to_stdout
    end
  end

  context 'main' do
    it 'can bake an image' do
      m = Linecook::CLI.new
      m.options = {name: 'foo'}
      m.bake
    end
  end

  context 'crypto' do

    it 'can generate keys' do
      c = Crypto.new
      expect{c.keygen}.to output(/:KY:/).to_stdout
    end

  end
end
