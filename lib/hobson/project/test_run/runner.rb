module Hobson::Project::TestRun::Runner

  @queue = :run_tests

  def self.perform project_name, test_run_id, job_index
    Hobson.log_to_a_tempfile{
      project = Hobson::Project[project_name] or raise "Project Not Found!"
      test_run = project.test_runs(test_run_id) or raise "Test Run Not Found!"
      job = test_run.jobs[job_index] or raise "Job Not Found!"
      job.run_tests!
    }
  end

end
