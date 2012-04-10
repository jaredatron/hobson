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
    :complete,
    :ready_to_finish_run,
    :finishing_test_run

  def abort!
    aborting! unless complete?
  end

  def running?
    checking_out_code_at.present? && !complete?
  end

  def errored?
    self['exception'].present?
  end

  def complete?
    complete_at.present? || test_run.aborted?
  end

  def status
    errored?              ? 'errored'                      :
    complete?             ? 'complete'                     :
    tearing_down?         ? 'tearing down'                 :
    saving_artifacts?     ? 'saving artifacts'             :
    running_tests?        ? 'running tests'                :
    preparing?            ? 'preparing'                    :
    checking_out_code?    ? 'checking out code'            :
    enqueued?             ? 'waiting to be run'            :
    ready_to_finish_run?  ? 'tests completed for this job' :
    finishing_test_run?   ? 'finishing test run'           :
    'waiting...'
  end

end
