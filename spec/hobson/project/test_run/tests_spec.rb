require 'spec_helper'

describe Hobson::Project::TestRun::Tests do

  subject{ Factory.tests }
  alias_method :tests, :subject

  worker_context do

    it { should be_an Enumerable }

    context "before detecting" do

      describe "#types" do
        subject{ Factory.tests.types.sort }
        it { should == [] }
      end

    end

    context "after detecting" do

      before{ tests.detect! }

      it "should have a length of 8" do
        tests.length.should == 8
      end

      it "should contain only Test objects" do
        tests.each{|test| test.should be_a Hobson::Project::TestRun::Tests::Test }
      end

      it "should only contain waiting tests" do
        tests.each{|test| test.status.should == 'waiting'}
      end

      describe "#types" do
        it "should return ['feature', 'spec']" do
          tests.types.to_set.should == %w{feature spec}.to_set
        end
      end

    end

  end

  describe "balance_for!" do

    def balance_for! est_runtimes, number_of_jobs
      tests = Factory.tests
      est_runtimes.each_with_index{|est_runtime, index|
        tests << "features/#{index}.feature"
        tests["features/#{index}.feature"].est_runtime = est_runtime
      }
      tests.balance_for! number_of_jobs
      tests.map(&:job).sort
    end

    context "when we have never run these tests before" do
      it "should give each job an equal number of tests" do
        balance_for!([nil,nil,nil,nil,nil,nil,nil,nil,nil,nil], 1).should == [0,0,0,0,0,0,0,0,0,0]
        balance_for!([nil,nil,nil,nil,nil,nil,nil,nil,nil,nil], 2).should == [0,0,0,0,0,1,1,1,1,1]
        balance_for!([nil,nil,nil,nil,nil,nil,nil,nil,nil,nil], 3).should == [0,0,0,0,1,1,1,2,2,2]
        balance_for!([nil,nil,nil,nil,nil,nil,nil,nil,nil,nil], 4).should == [0,0,0,1,1,2,2,3,3,3]
      end
    end

    context "when we have run these tests before" do
      it "should give each job a balanced number of tests" do
        balance_for!([ 1, 1, 1, 1, 1, 1, 1, 1, 1,10], 1).should == [0,0,0,0,0,0,0,0,0,0]
        balance_for!([ 1, 1, 1, 1, 1, 1, 1, 1, 1,10], 2).should == [0,1,1,1,1,1,1,1,1,1]
      end
    end

    # subject{
    #   Hobson::Project::TestRun::Tests.new(stub(
    #     :[] => nil, :[]= => nil, :data => {}
    #   ))
    # }

    # before{
    #   10.times{|i| tests["features/#{i}.feature"].status = "waiting" }
    # }

    # context "when we have never run these tests before" do
    #   it "should give each job an equal number of tests" do
    #     tests.map(&:job).should == [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil]
    #     tests.balance_for! 1
    #     tests.map(&:job).should == [0,0,0,0,0,0,0,0,0,0]
    #     tests.balance_for! 2
    #     tests.map(&:job).sort.should == [0,0,0,0,0,1,1,1,1,1]
    #     tests.balance_for! 3
    #     tests.map(&:job).sort.should == [0,0,0,0,1,1,1,2,2,2]
    #   end
    # end

    # context "when we have run these tests before" do
    #   before{
    #     [1,1,1,1,1,5,10].each_with_index{|est_runtime, index|
    #       tests.to_a[index].est_runtime = est_runtime
    #     }
    #   }
    #   it "should give each job a balanced number of tests" do
    #     debugger;1
    #     tests.map(&:job).should == [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil]
    #     tests.balance_for! 1
    #     tests.map(&:job).should == [0,0,0,0,0,0,0,0,0,0]
    #     tests.balance_for! 2
    #     tests.map(&:job).sort.should == [0,0,0,0,0,0,0,0,0,1]
    #     # tests.balance_for! 3
    #     # tests.map(&:job).sort.should == [0,0,0,0,1,1,1,2,2,2]
    #   end
    # end
  end

end

