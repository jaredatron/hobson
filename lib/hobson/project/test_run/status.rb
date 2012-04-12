class Hobson::Project::TestRun

  extend Hobson::Landmarks
  landmark :created, :enqueued_build, :started_building, :enqueued_jobs, :aborted

  def status
    errored?          ? 'errored'             :
    aborted?          ? 'aborted'             :
    failed?           ? 'failed'              :
    passed?           ? 'passed'              :
    complete?         ? 'complete'            :
    running?          ? 'running tests'       :
    enqueued_jobs?    ? 'waiting to be run'   :
    started_building? ? 'building'            :
    enqueued_build?   ? 'waiting to be built' :
    'waiting...'
  end

  alias_method :abort!,     :aborted!
  alias_method :started?,   :enqueued_jobs?
  alias_method :started_at, :enqueued_jobs_at

  def aborted?
    # bypass the cache and read from redis every time
    redis_hash.get('aborted_at').present?
  end

  def running?
    jobs.present? && jobs.any?(&:running?) && !complete? && !aborted?
  end

  def errored?
    jobs.any?(&:errored?)
  end

  def complete?
    aborted? || (jobs.present? && jobs.all?(&:complete?))
  end

  def complete_at
    jobs.map(&:complete_at).compact.sort.last if complete?
  end

  def passed?
    complete? && tests.map(&:result).all?{|result| result == 'PASS'}
  end

  def failed?
    complete? && !passed?
  end

end
