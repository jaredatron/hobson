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

  def complete?
    jobs.present? && jobs.all?(&:complete?)
  end

  def started_at
    enqueued_build_at
  end

  def complete_at
    jobs.map(&:complete_at).compact.sort.last if complete?
  end

end
