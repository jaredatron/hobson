require 'spec_helper'

describe "undefined scenarios should fail spec" do

  let(:project) { Factory.project }
  let(:test_run){ Factory.test_run(project, 'origin/testing_missing_step_definition') }

  worker_context do
    test_run.build!
    test_run.jobs.each(&:run_tests!)
    debugger;1
  end

end
