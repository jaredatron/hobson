class Hobson::Project::TestRun::Job

  autoload :TestExecutor, 'hobson/project/test_run/job/test_executor'
  autoload :Runner,       'hobson/project/test_run/job/runner'
  autoload :Sprinter,     'hobson/project/test_run/job/sprinter'

  attr_reader :test_run, :index
  delegate :workspace, :to => :test_run

  def initialize test_run, index
    @test_run, @index = test_run, index
  end

  def tests
    test_run.tests.find_all{|test| test.job == index }
  end

  def tests_needing_to_be_run
    return [] if test_run.aborted?
    tests.find_all{|test| test.needs_run? }
  end

  def while_tests_needing_to_be_run
    index = 0
    while (tests = tests_needing_to_be_run).present?
      yield tests, index += 1
    end
  end

  def tries
    tests.map(&:tries).sort.last
  end

  def est_runtime
    tests.map(&:est_runtime).compact.sum
  end

  def runtime
    (complete_at || Time.now) - (checking_out_code_at || Time.now)
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
