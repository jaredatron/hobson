require 'spec_helper'

describe "undefined scenarios should fail spec" do

  worker_context do

    let(:sha){ git_rev_parse('origin/testing_missing_step_definition') }
    let(:project) { Factory.project }

    context "when running a scenario with an undefined step" do
      it "should fail" do
        Resque.stub(:workers).and_return(stub(:length => 2))
        test_run = project.run_tests!(:sha => sha, :requestor => 'The TestEnvironment')
        Resque.run!
        Resque.run!
        tests = project.test_runs.last.tests
        tests.map{|t| [t.name,t.result] }.to_set.should == Set[
          ["This scenario outline should fail because it has an example that fails", "FAIL"],
          ["This scenario should pass", "PASS"],
          ["This scenario should fail because it has a missing step definition", "FAIL"],
          ["This scenario outline should fail because it has a missing step definition", "FAIL"],
          ["This scenario outline should pass because it doesnt have a missing step definition", "PASS"],
          ["As an admin I should be able to create a post", "PASS"],
          ["As an admin I should be able to create a post and delete it", "PASS"],
        ]
      end
    end

  end

end
