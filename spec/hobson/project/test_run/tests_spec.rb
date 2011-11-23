require 'spec_helper'

describe Hobson::Project::TestRun::Job::Tests do

  subject{ Factory.tests }
  alias_method :tests, :subject

  worker_context do

    it { should be_an Enumerable }

    it "should" do
    end

    describe "#types" do
      subject{ Factory.tests.types.sort }
      alias_method :types, :subject
      it { should be_an Enumerable }
      it { should == %w{featrures specs}.sort }
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

