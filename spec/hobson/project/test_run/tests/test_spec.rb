require 'spec_helper'

describe Hobson::Project::TestRun::Tests::Test do

  let(:test_run){ Factory.test_run }
  let(:project) { test_run.project }
  let(:tests) {
    3.times{|n|
      test_run.tests.add("scenario:#{n}.feature")
      test_run.tests.add("spec:#{n}_spec.rb")
    }
    test_run.tests
  }
  let(:test) { tests['scenario:1.feature'] }
  subject{ test }

  worker_context do

    %w{type name job est_runtime started_at completed_at result}.each do |attr|
      it { should respond_to :"#{attr}"  }
      it { should respond_to :"#{attr}="  }
    end

    describe "calculate_estimated_runtime!" do

      context "when this test has never been run before" do
        it "should calculate nil" do
          test.calculate_estimated_runtime!
          test.est_runtime.should == Hobson::Project::TestRun::Tests::Test.minimum_est_runtime
        end
      end

      context "when this test has been run before" do
        before{
          now = Time.now
          runtimes = 10.times.map{ rand * 1000 }
          runtimes.each{|r| project.test_runtimes[test.id] << r}
          @est_runtime = runtimes.sum / runtimes.size
        }
        it "should calculate the average runtime" do
          test.est_runtime.should be_nil
          test.calculate_estimated_runtime!
          test.est_runtime.should == @est_runtime
        end
      end

    end

  end

end
