require 'spec_helper'

describe Hobson do

  client_context do

    describe "#root" do
      subject{ Hobson.root }
      it { should == ClientWorkingDirectory.path }
    end

    describe "#config_path" do
      subject{ Hobson.config_path }
      it { should == ClientWorkingDirectory.path + 'config/hobson.yml' }
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
      it { should == WorkerWorkingDirectory.path + 'config.yml' }
    end

    describe "#config" do
      subject{ Hobson.config }
      it { should be_a Hash }
    end

  end

  either_context do

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
