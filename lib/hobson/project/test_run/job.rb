class Hobson::Project::TestRun::Job

  attr_reader :test_run, :index
  delegate :logger, :workspace, :to => :test_run

  def initialize test_run, index
    @test_run, @index = test_run, index
  end

  def tests
    test_run.tests.find_all{|test| test.job == index }
  end

  def test_needing_to_be_run
    tests.find_all{|test| !test.pass? && test.tries <= Hobson.config[:max_retries] }
  end

  def est_runtime
    tests.map(&:est_runtime).compact.sum
  end

  def runtime
    tests.map(&:runtime).compact.sum
  end

  def inspect
    "#<#{self.class} #{index}>"
  end
  alias_method :to_s, :inspect

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project::TestRun::Job")
  end

end

require "hobson/project/test_run/job/persistence"
require "hobson/project/test_run/job/status"
require "hobson/project/test_run/job/hooks"
require "hobson/project/test_run/job/artifacts"
require "hobson/project/test_run/job/actions"
