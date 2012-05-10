class Hobson::Project

  autoload :Workspace,    'hobson/project/workspace'
  autoload :TestRun,      'hobson/project/test_run'
  autoload :TestRuntimes, 'hobson/project/test_runtimes'

  class << self

    def create origin=current_origin, name=nil
      name = name_from_origin(origin) if name.blank?
      project = new(name)
      project.origin = origin
      project
    end

    def find name
      project = new(name)
      project.new_record? ? nil : project
    end
    alias_method :[], :find

    def current
      origin = current_origin
      name = name_from_origin(origin)
      find(name) || create(origin, name)
    end

    def current_origin
      path = Hobson.root
      raise "#{path} this doesnt look like a git project" unless path.join('.git').directory?
      `cd #{path.to_s.inspect} && git config --get remote.origin.url`.chomp
    end

    def name_from_origin origin
      origin.scan(%r{/([^/]+?)(?:/|\.git)?$}).try(:first).try(:first) rescue
        raise "unable to parse project name from origin #{origin.inspect}"
    end

  end

  attr_reader :name
  def initialize name
    @name = name
  end

  %w{origin homepage}.each{|attr|
    define_method(:"#{attr}"){ redis[attr] }
    define_method(:"#{attr}="){|v| redis[attr] = v }
  }

  def origin
    redis['origin']
  end

  GITHUB_ORIGIN = %r{^(?:git@github.com:|git://github.com/|https?://.+?@github.com/)([^/]+)/([^/]+)\.git$}
  def origin= origin
    redis['origin'] = origin
    if self.homepage.nil? && origin =~ GITHUB_ORIGIN
      self.homepage = "https://github.com/#{$1}/#{$2}"
    end
  end

  def homepage
    redis['homepage']
  end

  def homepage= homepage
    redis['homepage'] = homepage
  end

  def workspace
    @workspace ||= Workspace.new(self)
  end

  def test_runtimes
    @test_runtimes ||= TestRuntimes.new(self)
  end

  def test_run_ids
    @test_run_ids ||= redis.zrange(:test_runs, 0, 99999999).reverse
  end

  def test_runs id=nil
    return TestRun.find(self, id) if id.present?
    @test_runs ||= test_run_ids.map{|id| TestRun.find(self, id) }.compact
  end

  # create a test_run and then add it to our memoized attributes
  def create_test_run options = {}
    TestRun.create(self, options).tap{|test_run|
      @test_run_ids << test_run.id if @test_run_ids.present?
      @test_runs << test_run if @test_runs.present?
    }
  end

  def run_tests! options = {}
    create_test_run(options).tap(&:enqueue!)
  end

  def new_record?
    !Hobson.redis.sismember(:projects, name)
  end

  def redis
    @redis ||= begin
      Hobson.redis.sadd(:projects, name) if new_record?
      Redis::Namespace.new("Project:#{name}", :redis => Hobson.redis)
    end
  end

  def delete
    redis.keys.each{|key| redis.del key }
    Hobson.redis.srem(:projects, name)
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

end
