class Hobson::Project

  autoload :Workspace, 'hobson/project/workspace'
  autoload :TestRun,   'hobson/project/test_run'

  class << self
    alias_method :[], :new
  end

  attr_reader :name
  def initialize name = Hobson::Project.current_project_name
    @name = name
  end

  def workspace
    @workspace ||= Workspace.new(self)
  end

  def test_runs id=nil
    return TestRun.new(self, id) if id.present?
    @test_runs ||= redis.keys \
      .inject([]){|ids, key| key =~ /^TestRun:([\w-]+)$/ and ids << $1; ids } \
      .sort.map{|id| TestRun.new(self, id) }
  end

  def run_tests! sha = Hobson::Project.current_sha
    test_run = TestRun.new(self)
    test_run.sha = sha
    test_run.enqueue!
    test_run
  end

  def redis
    @redis ||= Redis::Namespace.new("Project:#{name}", :redis => Hobson.redis)
  end

  def logger
    @logger ||= Log4r::Logger.new("Hobson::Project(#{name})")
  end

  def inspect
    "#<#{self.class} #{name}>"
  end
  alias_method :to_s, :inspect

  def == other
    self.name == other.name
  end

  private

  def self.current_project_name
    @current_project_name ||= begin
      `git config --get remote.origin.url`.scan(%r{/([^/]+)\.git}).try(:first).try(:first) or
        raise "unable to parse project name from remote origin url"
    end
  end

  def self.current_sha
    @current_sha ||= begin
      `git rev-parse HEAD`.chomp or raise "unable to get current sha"
      # TODO make sure the current sha is pushed to origin
    end
  end

end
