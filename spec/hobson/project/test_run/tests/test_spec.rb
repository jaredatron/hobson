require 'spec_helper'

describe Hobson::Project::TestRun::Tests::Test do

  subject{ Factory.test('factoried.feature') }
  alias_method :test, :subject

  worker_context do

    %w{job est_runtime started_at completed_at result}.each do |attr|
      it { should respond_to :"#{attr}"  }
      it { should respond_to :"#{attr}=" }
    end

    describe "calculate_estimated_runtime!" do

      context "when this test has never been run before" do
        it "should calculate nil" do
          test.calculate_estimated_runtime!
          test.est_runtime.should == Hobson::Project::TestRun::Tests::Test::MINIMUM_ESTIMATED_RUNTIME
        end
      end

      context "when this test has been run before" do
        before{
          now      = Time.now
          @runtimes = 10.times.map{ (rand * 1000).to_i.to_f }
          10.times{ |i|
            test = Factory.test('factoried.feature')
            test.job          = 0
            test.result       = 'PASS'
            test.started_at   = now - @runtimes[i]
            test.completed_at = now
          }
        }
        it "should calculate the average runtime" do
          test.est_runtime.should be_nil
          test.calculate_estimated_runtime!
          test.est_runtime.should == @runtimes.inject(&:+) / @runtimes.size
        end
      end

    end

  end

end
