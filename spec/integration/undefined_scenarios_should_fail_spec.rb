require 'spec_helper'

describe "undefined scenarios should fail spec" do

  let(:project) { Factory.project }

  worker_context do

    context "when running a scenario with an undefined step" do
      it "should fail" do
        Resque.stub(:workers).and_return(stub(:length => 2))
        test_run = project.run_tests!('origin/testing_missing_step_definition', 'rspec')
        Resque.run!
        Resque.run!
        tests = project.test_runs.last.tests
        tests.map{|t| [t.name,t.result] }.to_set.should == Set[
          ["This schenario should pass", "PASS"],
          ["This schenario should fail because it has a missing step definition", "FAIL"],
          ["As an admin I should be able to create a post and delete it", "PASS"],
          ["As an admin I should be able to create a post", "PASS"],
        ]
      end
    end

  end

end
