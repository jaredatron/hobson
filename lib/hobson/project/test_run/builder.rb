class Hobson::Project::TestRun::Builder

  @queue = :hobson

  def self.perform project_name, test_run_id
    Hobson.log_to_a_tempfile{
      project  = Hobson::Project.find(project_name) or raise "project not found: #{project_name.inspect}"
      test_run = project.test_runs(test_run_id)     or raise "test run not found: #{test_run_id.inspect}"
      test_run.build!
    }
  end

end
