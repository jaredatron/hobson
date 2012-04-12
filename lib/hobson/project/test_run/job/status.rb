class Hobson::Project::TestRun::Job

  extend Hobson::Landmarks
  landmark \
    :created,
    :enqueued,
    :checking_out_code,
    :preparing,
    :running_tests,
    :recording_test_runtimes,
    :saving_artifacts,
    :tearing_down,
    :aborting,
    :complete

  alias_method :aborted?, :aborting?

  def running?
    checking_out_code_at.present? && !complete?
  end

  def errored?
    self['exception'].present?
  end

  def complete?
    complete_at.present?
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
