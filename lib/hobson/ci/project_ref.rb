# a hobson ci project is a Hobson::Project and a git ref
class Hobson::CI::ProjectRef

  HISTORY_LENGTH = 10

  class << self

    def create project_name, ref
      Hobson::Project.find(project_name) or raise "unknown project #{project_name.inspect}"
      ref.present? or raise "invalid gir ref #{ref.inspect}"
      new(project_name, ref).save
    end

    def find id
      project_name, ref = id.scan(/^(.+?):(.+)$/).first
      project_ref = new(project_name, ref)
      project_ref.new_record? ? nil : project_ref
    end

  end

  attr_reader :project_name, :ref

  def initialize project_name, ref
    @project_name, @ref = project_name, ref
  end

  def id
    "#{project_name}:#{ref}"
  end

  def project
    @project ||= Hobson::Project.find(project_name)
  end

  def current_sha_untested?
    current_sha.present? && shas.exclude?(current_sha)
  end

  def running_tests?
    test_runs.any?{|test_run| test_run.present? && test_run.running? }
  end

  def need_test_run?
    current_sha_untested?
  end

  def run_tests! sha=current_sha
    test_run = project.run_tests!(
      :sha            => sha,
      :requestor      => 'CI',
      :fast_lane      => true,
      :ci_project_ref => self
    )
    index_test_run(test_run)
    test_run
  end

  def index_test_run test_run
    redis.pipelined{ # single request
      redis.lpush(:shas,         test_run.sha)
      redis.lpush(:test_run_ids, test_run.id)
      redis.ltrim(:shas,         0, HISTORY_LENGTH)
      redis.ltrim(:test_run_ids, 0, HISTORY_LENGTH)
    }
  end

  %w{shas test_run_ids}.each{|list|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{list}
        @#{list} ||= begin
          values = redis.lrange(:#{list}, 0, HISTORY_LENGTH-1)
          Array.new(HISTORY_LENGTH).zip(values).map(&:last) # pad array to HISTORY_LENGTH
        end
      end
    RUBY
  }

  def test_runs
    @test_runs ||= test_run_ids.map{|id| id.nil? ? nil : project.test_runs(id) }
  end

  def test_run_statuses
    @test_run_statuses ||= test_runs.map{|tr| tr.nil? ? 'nil' : tr.status}
  end

  def current_sha
    @current_sha or begin
      cmd          = %(cd #{Hobson.root.to_s.inspect} && git ls-remote #{project.origin.inspect} #{ref.inspect})
      result       = `#{cmd}`
      @current_sha = result.scan(/(\b[0-9a-f]{5,40}\b)/).try(:first).try(:first)
      if !$?.success? || @current_sha.blank?
        raise "failed getting remote sha for #{project.origin.inspect} #{ref.inspect}\n#{cmd.inspect} failed"
      end
    end
    @current_sha
  end

  def new_record?
    !Hobson::CI.redis.sismember(:project_refs, id)
  end

  def save
    Hobson::CI.redis.sadd(:project_refs, id)
    self
  end

  def delete
    redis.keys.each{|key| redis.del key}
    Hobson::CI.redis.srem(:project_refs, id)
    self
  end

  def inspect
    "#<#{self.class} #{id}>"
  end
  alias_method :to_s, :inspect

  def == other
    other.is_a?(self.class) && self.id == other.id
  end

  def redis
    @redis ||= Redis::Namespace.new("Project:#{id}", :redis => Hobson::CI.redis)
  end

end
