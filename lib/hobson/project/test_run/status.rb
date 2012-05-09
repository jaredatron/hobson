class Hobson::Project::TestRun

  extend Hobson::Landmarks
  landmark :created, :enqueued_build, :started_building, :enqueued_jobs, :aborted

  def status
    errored?             ? 'errored'             :
    aborted?             ? 'aborted'             :
    hung?                ? 'hung'                :
    failed?              ? 'failed'              :
    passed?              ? 'passed'              :
    complete?            ? 'complete'            :
    running?             ? 'running tests'       :
    enqueued_jobs?       ? 'waiting to be run'   :
    started_building?    ? 'building'            :
    enqueued_build?      ? 'waiting to be built' :
    'unknown'
  end

  alias_method :abort!, :aborted!
  alias_method :started?,   :enqueued_jobs?
  alias_method :started_at, :enqueued_jobs_at

  def aborted?
    # bypass the redis_hash cache and read from redis every time
    @aborted ||= redis_hash.get('aborted_at').present?
  end

  def running?
    !complete? && jobs.present? && jobs.any?(&:running?)
  end

  def errored?
    @errored ||= jobs.any?(&:errored?)
  end

  def complete?
    aborted? || errored? || (jobs.present? && jobs.all?(&:complete?))
  end

  def complete_at
    jobs.map(&:complete_at).compact.sort.last if complete?
  end

  def passed?
    complete? && tests.all?(&:pass?)
  end

  def failed?
    complete? && !passed?
  end

  def hung?
    complete? && tests.any?(&:hung?)
  end

end
