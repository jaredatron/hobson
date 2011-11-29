module Hobson::Project::TestRun::Builder

  @queue = :build_test_run

  def self.perform project_name, test_run_id
    Hobson.log_to_a_tempfile{
      Hobson::Project.new(project_name).test_runs(test_run_id).build!
    }
  end

end
