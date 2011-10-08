module Hobson::BuildTestRun

  @queue = :build_test_run

  def self.perform project_name, test_run_id
    Hobson::Project.new(project_name).test_runs(test_run_id).build!
  end

end
