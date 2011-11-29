module Hobson::Project::TestRun::Runner

  @queue = :run_tests

  def self.perform project_name, test_run_id, job_index
    Hobson.log_to_a_tempfile{
      Hobson::Project[project_name].test_runs(test_run_id).jobs[job_index].run_tests!
    }
  end

end
