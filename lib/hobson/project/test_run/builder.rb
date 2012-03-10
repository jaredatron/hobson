module Hobson::Project::TestRun::Builder

  @queue = :build_test_run

  def self.perform project_name, test_run_id
    Hobson.log_to_a_tempfile{
      test_run = Hobson::Project[project_name].test_runs(test_run_id) or raise "Test Run Not Found!"
      test_run.build!
    }
  end

end
