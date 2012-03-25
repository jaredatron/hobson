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

  def check_for_new_sha!
    create_test_run! if current_sha_untested?
  end

  def current_sha_untested?
    shas.exclude? current_sha
  end

  def create_test_run! sha=current_sha
    test_run = project.run_tests!(sha, "CI:#{id}")
    redis.pipelined{ # single request
      redis.lpush(:shas,              sha)
      redis.lpush(:test_run_ids,      test_run.id)
      redis.ltrim(:shas,              0, HISTORY_LENGTH)
      redis.ltrim(:test_run_ids,      0, HISTORY_LENGTH)
    }
    test_run
  end

  %w{shas test_run_ids}.each{|list|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{list}
        @#{list} ||= redis.lrange(:#{list}, 0, HISTORY_LENGTH-1)
      end
    RUBY
  }

  def history
    @history ||= shas.zip(test_run_ids, test_run_statuses)
  end

  def test_runs
    @test_runs ||= test_run_ids.map{|id| project.test_runs(id) }
  end

  def test_run_statuses
    @test_run_statuses ||= test_runs.map(&:status)
  end

  # def status
  #   @status ||= begin
  #     # find the most recently complete test run's status
  #     test_run = test_run_statuses.find(&:complete)
  #     # if we dont have one we dont have a status, otherwise if its passed its green otherwise red
  #     test_run.nil? ? nil : test_run.status == 'passed' ? 'green' : 'red'
  #   end
  # end

  # # returns a hash of sha => test_run_id
  # def test_run_index
  #   @test_run_index ||= redis.hgetall(:test_run_index)
  # end

  # def shas
  #   test_run_index.keys
  # end

  # def test_run_ids
  #   test_run_index.values
  # end

  # # a redis hash of sha => test_run_result
  # def test_run_results
  #   @test_run_results ||= redis.hgetall(:test_run_results)
  # end

  # def test_runs
  #   @test_runs ||= redis.hgetall(:test_runs).each{|sha,test_run_id|
  #     project.test_runs(test_run_id)
  #   }
  # end

  # def test_run_results
  #   @test_run_results ||= redis.hgetall(:test_runs).each{|sha,test_run_id|
  #   @test_runs ||= redis.hgetall(:test_runs).each{|sha,test_run_id|
  #     project.test_runs(itest_run_id)
  #   }
  # end

  def current_sha
    @current_sha or begin
      cmd          = %(cd #{Hobson.root.to_s.inspect} && git ls-remote #{project.origin.inspect} #{ref.inspect})
      result       = `#{cmd}`
      @current_sha = result.scan(/(\b[0-9a-f]{5,40}\b)/).try(:first).try(:first)
      if !$?.success? || @current_sha.blank?
        raise "failed getting remote sha for #{origin_url.inspect} #{ref.inspect}\n#{cmd.inspect} failed"
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
