require 'spec_helper'

describe Hobson::Project::TestRun do

  subject{ Factory.test_run }
  alias_method :test_run, :subject

  either_context do

    describe "#data" do
      it "should return a hash" do
        test_run.data.should be_a Hash
      end
      it "should be a clone of the data at the time" do
        data1 = test_run.data
        test_run[:a] = :b
        test_run.data.should == data1.merge('a' => :b)
      end
    end

    %w{created enqueued_build started_building enqueued_jobs}.each do |landmark|
      it { should respond_to "#{landmark}!" }
      it { should respond_to "#{landmark}_at" }
      context "#{landmark} landmark" do
        before{ test_run['created_at'] = nil }
        it "should return a Time" do
          test_run.send("#{landmark}_at").should == nil
          test_run.send("#{landmark}!")
          test_run.send("#{landmark}_at").should be_a Time
        end
      end
    end

    it "should presist" do
      test_run1 = Factory.test_run
      test_run1[:sha] = '6841b60af66264906dc8c9fe0569aa1348e4bec2'
      test_run1.enqueued_build!
      test_run1.started_building!
      test_run1.enqueued_jobs!

      test_run2 = test_run1.project.test_runs(test_run1.id)
      test_run2.id.should == test_run1.id
      test_run2[:sha].should == '6841b60af66264906dc8c9fe0569aa1348e4bec2'
      test_run2.enqueued_build_at.should  == test_run2.enqueued_build_at
      test_run2.started_building_at.should == test_run2.started_building_at
      test_run2.enqueued_jobs_at.should   == test_run2.enqueued_jobs_at
    end

    describe "enqueue!" do
      it "should enqueue a Hobson::Project::TestRun::Builder in resque" do
        test_run.sha = "6841b60af66264906dc8c9fe0569aa1348e4bec2"
        Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Builder, test_run.project.name, test_run.id)
        test_run.enqueue!
      end
    end

    describe "status" do
      it "should accurately reflect the test run's status" do
        test_run = Factory.test_run
        Factory.job(test_run, 0)

        test_run.status.should == 'waiting...'

        test_run.enqueued_build!
        test_run.status.should == 'waiting to be built'

        test_run.started_building!
        test_run.status.should == 'building'

        test_run.enqueued_jobs!
        test_run.status.should == 'waiting to be run'

        test_run.jobs.first.checking_out_code!
        test_run.status.should == 'running tests'
      end
    end

  end

  worker_context do

    describe "tests" do
      subject { Factory.test_run.tests }
      alias_method :tests, :subject
      it { should be_a Hobson::Project::TestRun::Tests }
    end

    describe "build!" do

      context "when there are only 2 workers" do
        before do
          Resque.stub(:workers).and_return(stub(:length => 2))
        end

        it "should schedule schedule 2 jobs" do
          # test_run.workspace.should_receive(:checkout!).with(test_run.sha)
          # test_run.workspace.should_receive(:tests)
          Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, 0).once
          Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Runner, test_run.project.name, test_run.id, 1).once
          test_run.build!
          test_run.jobs.length.should == 2
        end

        it "should balance specs and features evenly across 2 jobs" do
          test_run.build!
          test_run.jobs.first.tests.map(&:name).sort.should == %w[
            features/a.feature
            features/b.feature
            features/c.feature
            features/d.feature
            features/e.feature
          ].sort
          test_run.jobs.last.tests.map(&:name).sort.should == %w[
            spec/a_spec.rb
            spec/b_spec.rb
            spec/c_spec.rb
            spec/d_spec.rb
            spec/e_spec.rb
          ].sort
        end

      end

    end

  end

end
