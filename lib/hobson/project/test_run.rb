require 'uuid'

class Hobson::Project::TestRun

  VALID_GIT_SHA = /\b[0-9a-f]{5,40}\b/

  autoload :Builder,         'hobson/project/test_run/builder'
  autoload :FastLaneBuilder, 'hobson/project/test_run/fast_lane_builder'
  autoload :Tests,           'hobson/project/test_run/tests'
  autoload :Job,             'hobson/project/test_run/job'

  class << self

    def create project, options={}
      test_run = new(project)
      options.each{|attr, value| test_run.send(:"#{attr}=", value) }
      test_run.sha ||= current_sha
      test_run.requestor ||= current_requestor
      test_run.sha =~ VALID_GIT_SHA or raise "invalid git sha #{test_run.sha}"
      test_run.save!
      test_run
    end

    def find project, id
      test_run = new(project, id)
      if test_run.new_record?
        # if you're looking for a test_run that does not exist it's probably
        # been removed by expiration and should be removed from the index set
        test_run.delete!
        return nil
      else
        return test_run
      end
    end

    private

    def current_sha
      @current_sha ||= begin
        `git rev-parse HEAD`.chomp or raise "unable to get current sha"
        # TODO make sure the current sha is pushed to origin
      end
    end

    def current_requestor
      `git var -l | grep GIT_AUTHOR_IDENT`.split('=').last.split(' <').first rescue ""
    end

  end

  delegate :workspace, :to => :project
  attr_reader :project

  def initialize project, id=nil
    @project, @id = project, id
  end

  def id
    @id ||= UUID.generate
  end

  def tests
    @tests ||= Tests.new(self)
  end

  def est_runtime
    jobs.map(&:est_runtime).sort.last
  end

  def duration
    return 0 unless running? || complete?
    (complete_at || Time.now) - (started_at || Time.now)
  end

  def jobs
    @jobs ||= tests.map(&:job).compact.uniq.sort.inject([]){|jobs, index|
      jobs[index] ||= Job.new(self, index)
      jobs
    }
  end

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project::TestRun")
  end

  def inspect
    "#<#{self.class} #{id}>"
  end
  alias_method :to_s, :inspect

  def == other
    self.id == other.id
  end

end

require "hobson/project/test_run/persistence"
require "hobson/project/test_run/actions"
require "hobson/project/test_run/status"
