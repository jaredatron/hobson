require 'spec_helper'

describe Hobson::Project::TestRun::Tests::Test do

  subject{ Factory.test('factoried.feature') }
  alias_method :test, :subject

  worker_context do

    %w{job status result runtime est_runtime}.each do |attr|
      it { should respond_to :"#{attr}"  }
      it { should respond_to :"#{attr}=" }
    end

    describe "calculate_estimated_runtime!" do

      it "should calculate nil" do
        test.est_runtime.should be_nil
        test.calculate_estimated_runtime!
        test.est_runtime.should be_nil
      end



    end

  end

end
