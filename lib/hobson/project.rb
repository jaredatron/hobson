class Hobson::Project

  autoload :Workspace, 'hobson/project/workspace'
  autoload :TestRun,   'hobson/project/test_run'

  class << self

    alias_method :[], :new

    def current
      raise "this doesnt look like a git project" unless Pathname.new('.git').directory?
      from_origin_url `git config --get remote.origin.url`.chomp
    end

    def from_origin_url origin_url
      name = origin_url.scan(%r{/([^/]+?)(?:/|\.git)?$}).try(:first).try(:first) or
        raise "unable to parse name from origin url #{origin_url.inspect}"
      project = new(name)
      project.url = origin_url
      project
    end

    def all
      Hobson.redis.keys.inject([]){ |projects, key|
        key =~ /^Project:(.*):url$/ and projects << self[$1]
        projects
      }
    end

  end

  attr_reader :name
  def initialize name
    @name ||= name
  end

  def url
    redis['url']
  end

  def url= url
    redis['url'] = url
  end

  def workspace
    @workspace ||= Workspace.new(self)
  end

  def test_runs id=nil
    if id.present?
      test_run = TestRun.new(self, id)
      return test_run.data.keys.present? ? test_run : nil
    end
    @test_runs ||= redis.keys \
      .inject([]){|ids, key| key =~ /^TestRun:([\w-]+)$/ and ids << $1; ids } \
      .sort.map{|id| TestRun.new(self, id) }
  end

  def run_tests! sha = current_sha
    test_run = TestRun.new(self)
    test_run.created!
    test_run.sha = sha
    test_run.enqueue!
    test_run
  end

  class Tests
    def runtimes
      @runtimes ||= []
    end
    def avg_runtime
      @avg_runtime ||= runtimes.present? ? runtimes.sum / runtimes.length.to_f : 0.0
    end
    def tries
      @tries ||= []
    end
    def avg_tries
      @avg_runtime ||= tries.present? ? tries.sum / tries.length.to_f : 0.0
    end
  end

  def tests
    tests = {}
    test_runs.each{|test_run|
      test_run.tests.each{|test|
        tests[test.name] ||= Tests.new
        runtime = test.runtime.to_f || 0.0
        tests[test.name].runtimes << runtime if test.pass? && runtime > 0.0
        tests[test.name].tries << test.tries if test.tries > 0
      }
    }
    tests
  end

  def redis
    @redis ||= Redis::Namespace.new("Project:#{name}", :redis => Hobson.redis)
  end

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project")
  end

  def inspect
    "#<#{self.class} #{name}>"
  end
  alias_method :to_s, :inspect

  def == other
    self.name == other.name
  end

  private

  def current_sha
    @current_sha ||= begin
      `git rev-parse HEAD`.chomp or raise "unable to get current sha"
      # TODO make sure the current sha is pushed to origin
    end
  end

end
