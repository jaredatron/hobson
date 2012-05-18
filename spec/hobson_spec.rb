require 'spec_helper'

describe Hobson do

  client_context do

    describe "#root" do
      subject{ Hobson.root }
      it { should == ClientWorkingDirectory.path }
    end

    describe "#config_path" do
      subject{ Hobson.config_path }
      it { should == ClientWorkingDirectory.path.join('config/hobson.yml').to_s }
    end

    describe "#config" do
      subject{ Hobson.config }
      it { should be_a Hash }
    end

  end

  worker_context do

    describe "#root" do
      subject{ Hobson.root }
      it { should == WorkerWorkingDirectory.path }
    end

    describe "#config_path" do
      subject{ Hobson.config_path }
      it { should == WorkerWorkingDirectory.path.join('config.yml').to_s }
    end

    describe "#config" do
      subject{ Hobson.config }
      it { should be_a Hash }
    end

  end

  either_context do

    describe "#encoding" do

      def test_encoding internal, external
        Encoding.default_internal.to_s.should eql internal
        Encoding.default_external.to_s.should eql external
      end

      after{
        RSpec::Mocks.teardown
        Hobson.reset_encoding!
      }

      it 'should have default encodings of utf-8' do
        test_encoding "UTF-8", "UTF-8"
      end

      it 'should set the encoding from the config file' do
        Hobson.stub(:config).and_return encoding: { internal: 'US-ASCII', external: 'ASCII-8BIT' }
        Hobson.reset_encoding!
        test_encoding 'US-ASCII', 'ASCII-8BIT'
      end

    end

    describe "#redis" do
      subject{ Hobson.redis }
      it { should be_a Redis::Namespace }

      describe ".namespace" do
        subject{ Hobson.redis.namespace }
        it { should == 'hobson' }
      end

      describe ".client" do
        describe ".host" do
          subject{ Hobson.redis.client.host }
          it { should == '127.0.0.1' }
        end
        describe ".port" do
          subject{ Hobson.redis.client.port }
          it { should == 6379 }
        end
      end

    end

  end


end
