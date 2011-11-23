require 'uuid'

class Hobson::Project::TestRun

  autoload :Tests, 'hobson/project/test_run/tests'
  autoload :Job,   'hobson/project/test_run/job'

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

  def jobs
    @jobs ||= keys \
      .inject([]){|indices, key| key =~ /^job:(\d+):.*/ and indices << $1.to_i; indices } \
      .uniq.sort.map{|index| Job.new(self, index) }
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

%w{class_methods persistence actions status}.each{|file| require "hobson/project/test_run/#{file}" }
