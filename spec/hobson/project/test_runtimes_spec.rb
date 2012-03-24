require 'spec_helper'

describe Hobson::Project::TestRuntimes do

  subject{ Factory.project.test_runtimes }
  alias_method :test_runtimes, :subject

  either_context do

    describe "#[]" do
      it "should return a Runtimes instance of the given test id" do
        test_runtimes['spec:spec/something_spec.rb'].should be_a Hobson::Project::TestRuntimes::Runtimes
      end
    end

    it "should persist upto #{Hobson::Project::TestRuntimes::MAX_REMEMBERED_RUNTIMES} runtimes" do
      20.times{|n| test_runtimes['spec:spec/something_spec.rb'] << n }
      test_runtimes['spec:spec/something_spec.rb'].to_a.should == [10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0,19.0]
    end

  end

end
