require 'spec_helper'

describe Hobson::Project::TestRun::Job do

  subject{ Factory.job }
  alias_method :job, :subject

  either_context do

    describe "#data" do
      it "should be a subset of test_run.data" do
        job.test_run['a'] = 'b'
        job['c'] = 'd'
        job.data.should == {'c' => 'd'}
      end
    end

    context "landmarks" do
      %w{enqueued checking_out_code preparing running_tests saving_artifacts tearing_down complete}.each do |landmark|
        it { should respond_to "#{landmark}!" }
        it { should respond_to "#{landmark}_at" }
        it "should convert strings to times" do
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
      it "should enqueue 1 Hobson::BuildTestRun resque job" do
        Resque.should_receive(:enqueue).with(Hobson::RunTests, job.test_run.project.name, job.test_run.id, job.index).once
        job.enqueue!
      end
    end

  end

  worker_context do

    describe "#tests" do
      subject{ super.tests }
      context "before being assigned tests" do
        it { should == [] }
      end
      context "after being assigned tests" do
        before{}
        it { should == [] }
      end
    end

    describe "#save_artifact" do

      it "should store a key in the redis hash and write a file to S3" do
        file = stub(:public_link => 'http://example.com')
        job.should_receive(:save_file).and_return(file)
        job.save_artifact('Gemfile').should == file
        job.artifacts.should == {'Gemfile' => 'http://example.com'}
      end

    end

  end

end
