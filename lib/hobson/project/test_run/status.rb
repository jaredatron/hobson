class Hobson::Project::TestRun

  extend Hobson::Landmarks
  landmark :enqueued_build, :started_building, :enqueued_jobs

  def status
    complete?         ? 'complete'            :
    enqueued_jobs?    ? 'running tests'       :
    started_building? ? 'building'            :
    enqueued_build?   ? 'waiting to be built' :
    'waiting…'
  end

  alias_method :created_at, :enqueued_build_at
  alias_method :started?,   :enqueued_jobs?
  alias_method :started_at, :enqueued_jobs_at

  def complete?
    jobs.present? && jobs.all?(&:complete?)
  end

  def complete_at
    jobs.map(&:complete_at).compact.sort.last if complete?
  end

  def green?
    complete? && tests.map(&:result).all?{|result| result == 'PASS'}
  end

  def red?
    complete? && !green?
  end

end
