require 'spec_helper'

describe "undefined scenarios should fail spec" do
  worker_context do

    let(:project){ Factory.project }

    it "should run the post processing hook at the end of the last job" do
      Resque.stub(:workers).and_return(stub(:length => 2))
      test_run = project.run_tests! :sha => git_rev_parse('origin/testing_post_processing')
      Resque.run! # build
      test_run.reload!
      test_run.jobs.size.should == 2
      Resque.run! # run tests
      test_run.reload!
      test_run.jobs.find_all{|j| j.post_processing_at.present? }.size.should == 1
      test_run.jobs.any?{|job| job.artifacts["coverage.tar.gz"].present? }.should be_true
    end

  end
end
