module Factory

  extend self

  def project name=ExampleProject::NAME
    Hobson::Project[name]
  end

  def workspace
    project.workspace
  end

  def test_run project=self.project
    test_run = Hobson::Project::TestRun.new(project)
    test_run.created!
    test_run.sha = ClientWorkingDirectory.current_sha
    test_run
  end

  def tests test_run=self.test_run
    test_run.tests
  end

  def test name, tests=self.tests
    tests << name
    tests[name]
  end

  def job test_run=self.test_run, index=0
    job = Hobson::Project::TestRun::Job.new(test_run, index)
    job.created!
    job
  end

end
