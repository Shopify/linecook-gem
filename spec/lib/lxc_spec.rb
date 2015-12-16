require File.expand_path('../../spec_helper.rb', __FILE__)

RSpec.describe Linecook::Lxc::Container do
  context 'local' do
    it 'can generate an lxc config' do
      container = Linecook::Lxc::Container.new
      match_fixture('lxc_base_config', container.config)
    end

    it 'can start an lxc container' do
      with_container do |container|
        expect(container.running?).to eq(true)
      end
    end

    it 'can determine the ip address' do
      with_container do |container|
        [container.ip].each do |ip|
          expect(IPAddress.valid?(ip)).to eq(true)
        end
      end
    end

    it 'can determine the pid' do
      with_container do |container|
        expect(container.pid).to_not be_empty
        expect(container.pid.to_i).to be > 0
      end
    end
  end
end
