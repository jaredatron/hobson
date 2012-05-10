require 'spec_helper'

describe Hobson::Project::TestRun::Job do

  subject{ Factory.job }
  alias_method :job, :subject

  either_context do

    describe "#data" do
      it "should be a subset of test_run.data" do
        job.test_run['a'] = 'b'
        job['a'].should be_nil
        job['c'] = 'd'
        job['c'].should == 'd'
      end
    end

    %w{created enqueued checking_out_code preparing running_tests saving_artifacts tearing_down complete}.each do |landmark|
      it { should respond_to "#{landmark}!" }
      it { should respond_to "#{landmark}_at" }
      context "#{landmark} landmark" do
        before{ job['created_at'] = nil }
        it "should return a Time" do
          job.send("#{landmark}_at").should == nil
          job.send("#{landmark}!")
          job.send("#{landmark}_at").should be_a Time
        end
      end
    end

    it "should presist" do
      test_run = Factory.test_run
      job = Hobson::Project::TestRun::Job.new(test_run, 1)
      job[:x] = 42
      job[:y] = 69
      job.keys.should == ['x', 'y']

      test_run = test_run.project.test_runs(test_run.id)
      job = Hobson::Project::TestRun::Job.new(test_run, 1)
      job[:x].should == 42
      job[:y].should == 69
      job.keys.should == ['x', 'y']
    end

    describe "#enqueue!" do
      it "should enqueue 1 Hobson::Project::TestRun::Job::Runner resque job" do
        Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Job::Runner, job.test_run.project.name, job.test_run.id, job.index).once
        job.enqueue!
      end
      context "when called with true" do
        it "should enqueue 1 Hobson::Project::TestRun::Job::Sprinter resque job" do
          Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Job::Sprinter, job.test_run.project.name, job.test_run.id, job.index).once
          job.enqueue! true
        end
      end
    end

  end

  worker_context do

    describe "#tests" do

      # context "before being assigned tests" do
      #   it "should be an empty array" do
      #     job.test.should == []
      #   end
      # end
      # context "after being assigned tests" do
      #   before{
      #     @tests = (0...4).map{|i| Hobson::Project::Tests::Test.new(job.test_run, "features/#{i}.feature") }
      #     job.test_run.tests.mock(:tests).and_return(@tests)
      #   }
      #   it "should be an array a subject of test_run.tests" do
      #     job.test_run.tests.length.should == 4
      #     job.test.should == []
      #   end
      # end
    end

    describe "#save_artifact" do

      it "should store a key in the redis hash and write a file to S3" do
        file = job.save_artifact('Gemfile')
        file.key.should == "testruns/#{job.test_run.id}/jobs/#{job.index}/Gemfile"
        file.content_type.should == "text/plain"
        job.artifacts.should == {'Gemfile' => "https://s3.amazonaws.com/test_bucket/#{file.key}"}
      end

    end

    describe "#run_tests!" do

    end

  end

end
