class Hobson::Project::TestRun::Job

  extend Hobson::Landmarks
  landmark \
    :created,
    :enqueued,
    :checking_out_code,
    :preparing,
    :running_tests,
    :tearing_down,
    :post_processing,
    :saving_artifacts,
    :complete

  def running?
    checking_out_code_at.present? && !complete?
  end

  delegate :should_abort?, :to => :test_run

  def errored?
    self['exception'].present?
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
