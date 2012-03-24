module Hobson::Project::TestRun::Runner

  @queue = :hobson

  def self.perform project_name, test_run_id, job_index
    Hobson.log_to_a_tempfile{
      project  = Hobson::Project.find(project_name) or raise "project not found: #{project_name.inspect}"
      test_run = project.test_runs(test_run_id)     or raise "test run not found: #{test_run_id.inspect}"
      job      = test_run.jobs[job_index]           or raise "job not found: #{job_index.inspect}"
      job.run_tests!
    }
  end

end
