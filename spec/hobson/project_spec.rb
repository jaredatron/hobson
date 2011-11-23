require 'spec_helper'

describe Hobson::Project do

  subject { Hobson::Project.current }
  alias_method :project, :subject

  client_context do

    describe "current" do

      context "when given no arguments" do

        it "should default to the name of the given git repo" do
          project.name.should == ExampleProject::NAME
        end

      end

    end

    describe "#run_tests!" do

      it "should return a new Hobson::Project::TestRun pointing at the current sha" do
        test_run = project.run_tests!
        test_run.should be_a Hobson::Project::TestRun
        test_run.sha.should == ClientWorkingDirectory.current_sha
      end

      it "should enqueue 1 Hobson::BuildTestRun resque job" do
        Resque.should_receive(:enqueue).with(Hobson::BuildTestRun, ExampleProject::NAME, anything).once
        project.run_tests!
      end

    end

    describe "#workspace" do
      it "should raise an error" do
        lambda{ project.workspace }.should raise_error
      end
    end

  end

  worker_context do

    describe "#workspace" do
      subject{ Hobson::Project.current.workspace }
      alias_method :workspace, :subject

      it { should be_a Hobson::Project::Workspace }
    end

  end

  either_context do

    describe "#redis" do

      subject{ Hobson::Project.current.redis }
      alias_method :redis, :subject

      it "should be a namespace" do
        redis.should be_a Redis::Namespace
        redis.should_not == Hobson.redis
        redis.namespace.should == "Project:#{ExampleProject::NAME}"
      end

    end

    describe "#test_runs" do

      it "should return an array of Hobson::Project::TestRun objects" do
        Hobson::Project.current.test_runs.should be_an Array
        test_runs = []
        test_runs << project.run_tests!
        Hobson::Project.current.test_runs.should == test_runs.sort_by(&:id)
        test_runs << project.run_tests!
        Hobson::Project.current.test_runs.should == test_runs.sort_by(&:id)
      end

      it "should return a test run when given an id" do
        test_run = project.run_tests!
        project.test_runs(test_run.id).should == test_run
        test_run = project.run_tests!
        project.test_runs(test_run.id).should == test_run
      end

    end

  end

  # describe "new" do

  #   context "when given no arguments" do

  #     before do
  #       Hobson.stub(:root).and_return(Pathname.new('/home/hobson/'))
  #       Hobson::Project.stub(:current_project_name).and_return('example_project')
  #       Hobson::Project.stub(:current_sha).and_return('5f0413d2a055f9ab69c4eb4c14a937c1869d60b7')
  #     end

  #     subject { Hobson::Project.new }

  #     it "should default to the name of the given git repo" do
  #       project.name.should == 'example_project'
  #     end

  #     it "should have a workspace" do
  #       project.workspace.should be_a Hobson::Project::Workspace
  #       project.workspace.root.should == Pathname.new('/home/hobson/projects/example_project')
  #     end

  #   end
  # end

  # describe "#redis" do

  #   subject{ Hobson::Project.new.redis }
  #   alias_method :redis, :subject

  #   it "should be in a namespace" do
  #     debugger;1
  #     redis.should be_a Redis::Namespace
  #     redis.should_not == Hobson.redis
  #     redis.namespace.should == "Project:#{WorkerHobsonDir::EXAMPLE_PROJECT_NAME}"
  #   end

  # end

  # describe "#run_tests!" do

  #   it "should return a new Hobson::Project::TestRun pointing at the current sha" do
  #     test_run = Hobson::Project.new.run_tests!
  #     test_run.should be_a Hobson::Project::TestRun
  #     test_run.sha.should == WorkerHobsonDir.current_sha
  #   end

  #   it "should enqueue 1 Hobson::BuildTestRun resque job" do
  #     Resque.should_receive(:enqueue).with(Hobson::BuildTestRun, 'random_project', anything).once
  #     Hobson::Project.new('random_project').run_tests!
  #   end

  # end

  # describe "#test_runs" do

  #   it "should return an array of Hobson::Project::TestRun objects" do

  #     Hobson::Project.new.test_runs.should be_an Array
  #     test_runs = []
  #     test_runs << project.run_tests!
  #     Hobson::Project.new.test_runs.should == test_runs.sort_by(&:id)
  #     test_runs << project.run_tests!
  #     Hobson::Project.new.test_runs.should == test_runs.sort_by(&:id)
  #   end

  #   it "should return a test run when given an id" do
  #     test_run = project.run_tests!
  #     project.test_runs(test_run.id).should == test_run
  #     test_run = project.run_tests!
  #     project.test_runs(test_run.id).should == test_run
  #   end

  # end

  # # it "should debug" do
  # #   debugger;1
  # # end

end
