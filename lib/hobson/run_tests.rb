module Hobson::RunTests

  @queue = :run_tests

  def self.perform project_name, test_run_id, job_index
    Hobson::Project.new(project_name).test_runs(test_run_id).jobs[job_index].run_tests!
  end

end
