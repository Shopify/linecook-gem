require File.expand_path('../../spec_helper.rb', __FILE__)

RSpec.describe Linecook::Build do
  it 'can start a build' do
    build = Linecook::Build.new('test', 'ubuntu-base.squashfs')
    build.start
  end
end
