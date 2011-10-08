require 'spec_helper'

describe Hobson::Project::TestRun do

  subject{ Factory.test_run }
  alias_method :test_run, :subject

  either_context do

    describe "#data" do
      it "should return a hash" do
        test_run = Hobson::Project::TestRun.new(Hobson::Project.new)
        test_run.data.should be_a Hash
        test_run[:a] = :b
        test_run.data.should == {'a' => :b}
      end
    end

    context "landmarks" do
      %w{enqueued_build started_building enqueued_jobs}.each do |landmark|
        it { should respond_to "#{landmark}!" }
        it { should respond_to "#{landmark}_at" }
        it "should convert strings to times" do
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
      it "should enqueue a Hobson::BuildTestRun in resque" do
        test_run.sha = "6841b60af66264906dc8c9fe0569aa1348e4bec2"
        Resque.should_receive(:enqueue).with(Hobson::BuildTestRun, test_run.project.name, test_run.id)
        test_run.enqueue!
      end
    end

    describe "build!" do

      before do
        # stub Resque.workers.length to return 2
        Resque.stub(:workers).and_return(stub(:length => 2))
        @test_run = Factory.test_run
        @test_run.sha = "6841b60af66264906dc8c9fe0569aa1348e4bec2"
        # stub workspace to do nothing (so we dont touch the filesystem)
        @test_run.workspace.stub(:checkout!).and_return(nil)
        @test_run.workspace.stub(:tests).and_return(%w{a b c d e f})
      end

      it "should create jobs and tests" do
        @test_run.build!
        @test_run.jobs.size.should == 2
        @test_run.jobs.map(&:tests).each{|tests|
          tests.size.should == 3
          tests.each{|test| test.status.should == 'waiting' }
        }
      end

    end

    describe "status" do
      it "should accurately reflect the test run's status" do
        test_run = Factory.test_run
        test_run.status.should == 'waiting…'

        test_run.enqueued_build!
        test_run.status.should == 'waiting to be built'

        test_run.started_building!
        test_run.status.should == 'building'

        test_run.enqueued_jobs!
        test_run.status.should == 'running tests'
      end
    end

  end

  # # describe ".ids" do

  # #   def create_a_test_run!
  # #     @test_run_ids ||= []
  # #     test_run = Factory.test_run
  # #     test_run[:x] = 1 # save at least one key
  # #     @test_run_ids << test_run.id
  # #     test_run
  # #   end

  # #   it "should return an array of all TestRun ids" do
  # #     Hobson::Project::TestRun.ids.should == []
  # #     5.times{ |n|
  # #       create_a_test_run!
  # #       ids = Hobson::Project::TestRun.ids
  # #       ids.length.should == n+1
  # #       ids.should == @test_run_ids.sort
  # #     }
  # #   end

  # # end

  # # describe ".get" do
  # #   it "should get a TestRun by id" do
  # #     test_run1 = Hobson::Project::TestRun.new
  # #     test_run1['something'] = rand
  # #     test_run2 = Hobson::Project::TestRun.get(test_run1.id)
  # #     test_run2.id.should == test_run1.id
  # #     test_run2['something'].should == test_run1['something']
  # #   end
  # # end

  # # describe ".all" do
  # #   it "should get all TestRuns" do
  # #     given_test_runs = (1..3).map{|n|
  # #       Hobson::Project::TestRun.new.tap{|t| t[:index] = n }
  # #     }
  # #     recieved_test_runs = Hobson::Project::TestRun.all

  # #     recieved_test_runs.length.should == given_test_runs.length
  # #     recieved_test_runs.each{|recieved_test_run|
  # #       given_test_run = given_test_runs.find{|tr| tr.id == recieved_test_run.id }
  # #       given_test_run.should_not be_nil
  # #       recieved_test_run[:index].should == given_test_run[:index]
  # #     }
  # #   end
  # # end



  # context "landmarks" do
  #   %w{enqueued_build started_building enqueued_jobs}.each do |landmark|
  #     it { should respond_to "#{landmark}!" }
  #     it { should respond_to "#{landmark}_at" }
  #     it "should convert strings to times" do
  #       test_run.send("#{landmark}_at").should == nil
  #       test_run.send("#{landmark}!")
  #       test_run.send("#{landmark}_at").should be_a Time
  #     end
  #   end
  # end

  # it "should presist" do
  #   test_run1 = Factory.test_run
  #   test_run1[:sha] = '6841b60af66264906dc8c9fe0569aa1348e4bec2'
  #   test_run1.enqueued_build!
  #   test_run1.started_building!
  #   test_run1.enqueued_jobs!

  #   test_run2 = test_run1.project.test_runs(test_run1.id)
  #   test_run2.id.should == test_run1.id
  #   test_run2[:sha].should == '6841b60af66264906dc8c9fe0569aa1348e4bec2'
  #   test_run2.enqueued_build_at.should  == test_run2.enqueued_build_at
  #   test_run2.started_building_at.should == test_run2.started_building_at
  #   test_run2.enqueued_jobs_at.should   == test_run2.enqueued_jobs_at
  # end

  # describe "enqueue!" do
  #   it "should enqueue a Hobson::BuildTestRun in resque" do
  #     test_run.sha = "6841b60af66264906dc8c9fe0569aa1348e4bec2"
  #     Resque.should_receive(:enqueue).with(Hobson::BuildTestRun, test_run.project.name, test_run.id)
  #     test_run.enqueue!
  #   end
  # end

  # describe "build!" do

  #   before do
  #     # stub Resque.workers.length to return 2
  #     Resque.stub(:workers).and_return(stub(:length => 2))
  #     @test_run = Factory.test_run
  #     @test_run.sha = "6841b60af66264906dc8c9fe0569aa1348e4bec2"
  #     # stub workspace to do nothing (so we dont touch the filesystem)
  #     @test_run.workspace.stub(:checkout!).and_return(nil)
  #     @test_run.workspace.stub(:tests).and_return(%w{a b c d e f})
  #   end

  #   it "should create jobs and tests" do
  #     @test_run.build!
  #     @test_run.jobs.size.should == 2
  #     @test_run.jobs.map(&:tests).each{|tests|
  #       tests.size.should == 3
  #       tests.each{|test| test.status.should == 'waiting' }
  #     }
  #   end

  # end

  # describe "status" do
  #   it "should accurately reflect the test run's status" do
  #     test_run = Factory.test_run
  #     test_run.status.should == 'waiting…'

  #     test_run.enqueued_build!
  #     test_run.status.should == 'waiting to be built'

  #     test_run.started_building!
  #     test_run.status.should == 'building'

  #     test_run.enqueued_jobs!
  #     test_run.status.should == 'running tests'
  #   end
  # end

end
