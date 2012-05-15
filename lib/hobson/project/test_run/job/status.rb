class Hobson::Project::TestRun::Job

  extend Hobson::Landmarks
  landmark \
    :created,
    :enqueued,
    :checking_out_code,
    :preparing,
    :running_tests,
    :saving_artifacts,
    :tearing_down,
    :complete

  # def abort!
  #   aborting! unless complete?
  # end

  def running?
    checking_out_code_at.present? && !complete?
  end

  def errored?
    # bypass the redis_hash cache and read from redis every time
    test_run.redis_hash.get("job:#{index}:exception").present?
  end

  def complete?
    complete_at.present? || test_run.aborted?
  end

  def status
    errored?           ? 'errored'           :
    complete?          ? 'complete'          :
    tearing_down?      ? 'tearing down'      :
    saving_artifacts?  ? 'saving artifacts'  :
    running_tests?     ? 'running tests'     :
    preparing?         ? 'preparing'         :
    checking_out_code? ? 'checking out code' :
    enqueued?          ? 'waiting to be run' :
    'waiting...'
  end

end
