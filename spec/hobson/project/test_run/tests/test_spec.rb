require 'spec_helper'

describe Hobson::Project::TestRun::Tests::Test do

  subject{ Factory.test }
  alias_method :test, :subject

  worker_context do

    %w{job status result runtime est_runtime}.each do |attr|
      it { should respond_to :"#{attr}"  }
      it { should respond_to :"#{attr}=" }
    end

  end

end
