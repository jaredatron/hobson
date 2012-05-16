require 'spec_helper'

describe Hobson::Project::TestRun do

  let(:project){ Factory.project }
  let(:sha){ git_rev_parse('origin/testing_test_detection') }
  let(:test_run){ Factory.test_run(sha, project) }
  subject{ test_run }

  either_context do

    describe "find" do
      it "should return nil and remove the id from the project test runs index if the given id finds a new_record" do
        test_run.save!

        Hobson::Project::TestRun.find(project, test_run.id).should be_a Hobson::Project::TestRun
        project.test_runs(test_run.id).should be_a Hobson::Project::TestRun
        project.test_run_ids.should include test_run.id

        # simulate the test run redis has expiring without being removed from the index
        test_run.redis.del("TestRun:#{test_run.id}")

        # reload the project
        project2 = Hobson::Project[project.name]

        Hobson::Project::TestRun.find(project2, test_run.id).should be_nil
        project2.test_runs(test_run.id).should be_nil
        project2.test_run_ids.should_not include test_run.id
      end
    end

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
      test_run1 = Factory.test_run('6841b60af66264906dc8c9fe0569aa1348e4bec2')
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
        Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Builder, test_run.project.name, test_run.id)
        test_run.enqueue!
      end
    end

    describe "status" do
      it "should accurately reflect the test run's status" do
        test_run = Factory.test_run
        test_run.tests.add('spec:models/user_spec.rb')
        test_run.tests.first.job = 0

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

        it "should schedule 2 jobs" do
          Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Job::Runner, test_run.project.name, test_run.id, 0).once
          Resque.should_receive(:enqueue).with(Hobson::Project::TestRun::Job::Runner, test_run.project.name, test_run.id, 1).once
          test_run.build!
          test_run.jobs.length.should == 2
        end

        it "should assign specs to one job worker and features to the other" do
          test_run.build!

          # using a set of sets allows comparison to not case about the other
          # of tests or what job got what set of tests
          expected_job_tests = Set[
            [
              "scenario:A",
              "scenario:B",
              "scenario:C",
              "scenario:D",
              "scenario:E",
              "scenario:As an admin I should be able to create a post",
              "scenario:As an admin I should be able to create a post and delete it",
              "scenario:As an admin I should be able to delete a post",
              "scenario:As an admin I should be able to view a post",
              "scenario:As a visitor I should be able to view a post",
            ].to_set,
            [
              "spec:spec/a_spec.rb",
              "spec:spec/b_spec.rb",
              "spec:spec/c_spec.rb",
              "spec:spec/d_spec.rb",
              "spec:spec/e_spec.rb",
              "spec:spec/flakey_spec.rb",
            ].to_set
          ]

          actual_jobs_tests = test_run.jobs.map{|job| job.tests.map(&:id).to_set }.to_set

          actual_jobs_tests.should == expected_job_tests
        end

      end

    end

  end

end
