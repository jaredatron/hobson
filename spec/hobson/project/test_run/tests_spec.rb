require 'spec_helper'

describe Hobson::Project::TestRun::Tests do

  subject{ Factory.tests }
  alias_method :tests, :subject

  describe "balance_for!" do

    before{
      10.times{|i| tests["features/#{i}.feature"].status = "waiting" }
    }

    context "when we have never run these tests before" do
      it "should give each job an equal number of tests" do
        tests.map(&:job).should == [nil,nil,nil,nil,nil,nil,nil,nil,nil,nil]
        tests.balance_for! 1
        tests.map(&:job).should == [0,0,0,0,0,0,0,0,0,0]
        tests.balance_for! 2
        tests.map(&:job).sort.should == [0,0,0,0,0,1,1,1,1,1]
        tests.balance_for! 3
        tests.map(&:job).sort.should == [0,0,0,0,1,1,1,2,2,2]
      end
    end

    context "when we have run these tests before" do
      before{
        [1,1,1,1,1,5,10].each_with_index{|est_runtime, index|
          tests.to_a[index].est_runtime = est_runtime
        }
      }
      it "should give each job a balanced number of tests" do

      end
    end
  end

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
          tests.types.should == %w{feature spec}.sort
        end
      end

    end

  end

  # either_context do

  #   it "should be an enumerable" do
  #     subject.should be_a Enumerable
  #   end

  #   describe "<<" do

  #     it "should create a new for the given names" do

  #       tests.should == []

  #       features = %w{
  #         features/login.feature
  #         features/signup.feature
  #       }

  #       specs = %w{
  #         spec/models/user_spec.rb
  #         spec/models/session_spec.rb
  #       }

  #       tests << features
  #       tests << specs

  #       tests.map(&:name).sort.should == (features+specs).sort

  #       tests << ['']

  #       tests.map(&:name).sort.should == (features+specs).sort

  #       (features+specs).each { |name|
  #         tests[name].name.should     == name
  #         tests[name].status.should   == 'waiting'
  #         tests[name].result.should   == nil
  #         tests[name].runtime.should == nil
  #       }

  #       (features+specs).each { |name|
  #         tests[name].status  = 'finished'
  #         tests[name].result  = 'PASS'
  #         tests[name].runtime = 10.34
  #       }

  #       (features+specs).each { |name|
  #         tests[name].status.should  == 'finished'
  #         tests[name].result.should  == 'PASS'
  #         tests[name].runtime.should == 10.34
  #       }

  #       tests.map(&:name).sort.should == (features+specs).sort

  #     end

  #     it "should not have duplicates" do
  #       tests.should == []
  #       tests << 'a'
  #       tests << 'a'
  #       tests << 'a'
  #       tests['a'].status  = 'finished'
  #       tests['a'].result  = 'PASS'
  #       tests['a'].runtime = 10.34
  #       tests.map(&:name).should == ['a']
  #     end

  #   end

  #   describe "estimated runtime" do

  #     before do
  #       @runtimes = 20.times.map{ rand }
  #       jobs      = 20.times.map{ Factory.job }
  #       jobs.each_with_index{ |job, index|
  #         job.tests['login.feature'].runtime = @runtimes[index]
  #       }
  #       jobs.map{|job| job.tests.first.runtime }.should == @runtimes
  #     end

  #     it "should read all the runtimes from all other test runs and return an average" do
  #       test = Factory.job.tests['login.feature']
  #       test.calculate_estimated_runtime!
  #       test.est_runtime.should == @runtimes.inject(&:+).to_f / @runtimes.size
  #     end

  #   end

  # end

end

