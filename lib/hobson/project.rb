class Hobson::Project

  autoload :Workspace,    'hobson/project/workspace'
  autoload :TestRun,      'hobson/project/test_run'
  autoload :TestRuntimes, 'hobson/project/test_runtimes'

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

  def test_runtimes
    @test_runtimes ||= TestRuntimes.new(self)
  end

  def test_runs id=nil
    if id.present?
      test_run = TestRun.new(self, id)
      test_run.data.keys.present? ? test_run : nil
    else
      @test_runs ||= redis.smembers(:test_runs).map{|id| TestRun.new(self, id) }
    end
  end

  def run_tests! sha = current_sha
    test_run = TestRun.new(self)
    test_run.requestor = current_requestor
    test_run.sha = sha
    test_run.save!
    test_run.enqueue!
    test_run
  end

  def redis
    @redis ||= begin
      Hobson.redis.sadd(:projects, name)
      Redis::Namespace.new("Project:#{name}", :redis => Hobson.redis)
    end
  end

  def delete
    Hobson.redis.srem(:projects, name)
    redis.keys.each{|key| redis.del key }
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

  def current_sha
    @current_sha ||= begin
      `git rev-parse HEAD`.chomp or raise "unable to get current sha"
      # TODO make sure the current sha is pushed to origin
    end
  end

  def current_requestor
    `git var -l | grep GIT_AUTHOR_IDENT`.split('=').last.split(' <').first
  rescue
    ""
  end

end
