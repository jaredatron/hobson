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

  def started?
    enqueued_jobs?
  end

  def started_at
    enqueued_jobs_at
  end

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
