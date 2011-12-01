class Hobson::Project::TestRun

  extend Hobson::Landmarks
  landmark :created, :enqueued_build, :started_building, :enqueued_jobs

  def status
    errored?          ? 'errored'             :
    complete?         ? 'complete'            :
    running?          ? 'running tests'       :
    enqueued_jobs?    ? 'waiting to be run'   :
    started_building? ? 'building'            :
    enqueued_build?   ? 'waiting to be built' :
    'waiting…'
  end

  alias_method :started?,   :enqueued_jobs?
  alias_method :started_at, :enqueued_jobs_at

  def running?
    jobs.any?{|job| job.checking_out_code_at.present? }
  end

  def errored?
    jobs.any?(&:errored?)
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
