class Hobson::Project::TestRun::Job

  extend Hobson::Landmarks
  landmark :enqueued, :checking_out_code, :preparing, :running_tests, :saving_artifacts, :tearing_down, :complete

  def error?
    self['exception'].present?
  end

  def status
    error?             ? 'error'             :
    complete?          ? 'complete'          :
    tearing_down?      ? 'tearing down'      :
    saving_artifacts?  ? 'saving artifacts'  :
    running_tests?     ? 'running tests'     :
    preparing?         ? 'preparing'         :
    checking_out_code? ? 'checking out code' :
    enqueued?          ? 'waiting to be run' :
    'waiting…'
  end

  # alias_method :started?, :checking_out_code?
  # alias_method :started_at, :checking_out_code_at
  # alias_method :completed_at, :complete_at

  # def status
  #   case step
  #   when "complete"
  #     "complete: #{error? ? 'ERROR' : success? ? 'PASS' : 'FAIL'}"
  #   when nil, ""
  #     "unscheduled"
  #   else
  #     step
  #   end
  # end

  # def success?
  #   test_results.all?{|result| result == 'PASS'} if complete?
  # end

  # def failure?
  #   test_results.any?{|result| result == 'FAIL'} if complete?
  # end

  # def error?
  #   redis["exception"].present?
  # end

end
