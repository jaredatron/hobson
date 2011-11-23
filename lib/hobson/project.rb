class Hobson::Project

  autoload :Workspace, 'hobson/project/workspace'
  autoload :TestRun,   'hobson/project/test_run'

  class << self

    alias_method :[], :new

    def current
      raise "this doesnt look like a git project" unless Pathname.new('.git').directory?
      url = `git config --get remote.origin.url`.chomp
      name = url.scan(%r{/([^/]+)\.git}).try(:first).try(:first) or
        raise "unable to parse name from url #{url.inspect}"
      project = new(name)
      project.url ||= url
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

  def test_runs id=nil
    return TestRun.new(self, id) if id.present?
    @test_runs ||= redis.keys \
      .inject([]){|ids, key| key =~ /^TestRun:([\w-]+)$/ and ids << $1; ids } \
      .sort.map{|id| TestRun.new(self, id) }
  end

  def run_tests! sha = current_sha
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

  def current_sha
    @current_sha ||= begin
      `git rev-parse HEAD`.chomp or raise "unable to get current sha"
      # TODO make sure the current sha is pushed to origin
    end
  end

end
