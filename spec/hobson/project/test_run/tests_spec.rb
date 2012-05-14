require 'spec_helper'

describe Hobson::Project::TestRun::Tests do

  let(:sha){ git_rev_parse('origin/slow_app_boot_specs_and_features') }
  let(:test_run){ Factory.test_run(sha) }
  let(:tests){ Factory.tests(test_run) }
  subject{ tests }

  worker_context do

    it { should be_an Enumerable }

    context "before detecting" do

      describe "#types" do
        subject{ Factory.tests.types.sort }
        it { should == [] }
      end

    end

    context "after detecting" do

      before{
        tests.test_run.workspace.checkout! tests.test_run.sha
        tests.test_run.workspace.prepare
        tests.detect!
      }

      it "should have a length of 16" do
        tests.length.should == 16
      end

      it "should contain only Test objects" do
        tests.each{|test| test.should be_a Hobson::Project::TestRun::Tests::Test }
      end

      it "should only contain waiting tests" do
        tests.each{|test| test.status.should == 'waiting'}
      end

      describe "#types" do
        it "should return ['scenario', 'spec']" do
          tests.types.to_set.should == %w{spec scenario}.to_set
        end
      end

    end


    describe "#balance!" do

      let(:test_run){
        test_run = Factory.test_run
        tests.each{|type, runtimes|
          runtimes.each_with_index{|runtime, index|
            test_run.tests.add("#{type}:#{index}")
            test_run.tests.last.est_runtime = runtime.minutes unless runtime.nil?
          }
        }
        test_run
      }

      def jobs
        test_run.tests.map(&:job).uniq.map{|index|
          Hobson::Project::TestRun::Job.new(test_run, index)
        }
      end

      def test_groups
        jobs.map{|job| job.tests.map(&:id) }
      end

      def job_est_runtimes
        jobs.map(&:est_runtime).map(&:to_f)
      end

      context "when all tests have no estimated runtime" do
        let(:tests){{
          :spec    => 120.times.map{ nil },
          :feature => 120.times.map{ nil },
        }}

        it "should balance" do
          test_run.tests.balance! 1.minute
          test_groups.should == [
            ( 0...60 ).map{|i| "spec:#{i}"    },
            (60...120).map{|i| "spec:#{i}"    },
            ( 0...60 ).map{|i| "feature:#{i}" },
            (60...120).map{|i| "feature:#{i}" },
          ]
          job_est_runtimes.should == [60.0,60.0,60.0,60.0]
        end
      end

      context "when there are a a few long running tests" do
        let(:tests){{
          :spec    => [10,9,8,7,6,5,4,3,2,1],
          :feature => [10,9,8,7,6,5,4,3,2,1],
        }}

        it "should balance" do
          test_run.tests.balance!
          test_groups.should == [
            %w{spec:0             },
            %w{spec:1             },
            %w{spec:2             },
            %w{spec:3             },
            %w{spec:4             },
            %w{spec:5             },
            %w{spec:6    spec:9   },
            %w{spec:7    spec:8   },
            %w{feature:0          },
            %w{feature:1          },
            %w{feature:2          },
            %w{feature:3          },
            %w{feature:4          },
            %w{feature:5          },
            %w{feature:6 feature:9},
            %w{feature:7 feature:8},
          ]
          job_est_runtimes.should == [600.0, 540.0, 480.0, 420.0, 360.0, 300.0, 300.0, 300.0, 600.0, 540.0, 480.0, 420.0, 360.0, 300.0, 300.0, 300.0]
        end
      end

      context "when there are a lot of fast tests" do
        let(:tests){{
          :spec    => [0.01,0.02,0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0],
          :feature => [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,2.0],
        }}

        it "should balance" do
          test_run.tests.balance!
          test_groups.should == [
            %w{spec:0     spec:1     spec:2     spec:3     spec:4    spec:5  spec:6  spec:7  spec:8 spec:10 spec:11},
            %w{spec:9     spec:12    spec:13    spec:14    spec:15   spec:16 spec:17 spec:18                       },
            %w{feature:0  feature:1  feature:2  feature:3                                                          },
            %w{feature:4  feature:5  feature:7  feature:8  feature:9 feature:11                                    },
            %w{feature:6  feature:12 feature:13 feature:15                                                         },
            %w{feature:10 feature:18 feature:19                                                                    },
            %w{feature:14 feature:16 feature:17                                                                    },
          ]
          job_est_runtimes.should == [57.0, 300.0, 60.0, 300.0, 300.0, 300.0, 300.0]
        end
      end

      context "when there are fine grained estimated runtimes" do
        let(:tests){{
          :spec    => [0.0123,0.1234,0.2345,0.3456,0.4567,0.5678,0.6789],
          :feature => [1.0123,1.1234,1.2345,1.3456,1.4567,1.5678,1.6789],
        }}

        it "should balance" do
          test_run.tests.balance!
          test_groups.should == [
            %w{spec:0     spec:1     spec:2     spec:3     spec:4    spec:5  spec:6},
            %w{feature:0  feature:1  feature:2  feature:3                          },
            %w{feature:4  feature:5  feature:6                                     },
          ]
          job_est_runtimes.should == [145.152, 282.948, 282.20400000000006]
        end
      end

    end

  end

  describe "balance_for!" do

    def balance_for! est_runtimes, number_of_jobs
      tests = Factory.tests
      est_runtimes.each_with_index{|est_runtime, index|
        tests.add("scenario:features/#{index}.feature")
        tests["scenario:features/#{index}.feature"].est_runtime = est_runtime
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

