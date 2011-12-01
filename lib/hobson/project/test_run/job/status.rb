class Hobson::Project::TestRun::Job

  extend Hobson::Landmarks
  landmark :created, :enqueued, :checking_out_code, :preparing, :running_tests, :saving_artifacts, :tearing_down, :complete

  def errored?
    self['exception'].present?
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
    'waiting…'
  end

end
