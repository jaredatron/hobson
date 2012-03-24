require 'spec_helper'

describe Hobson::Project::TestRuntimes::Runtimes do

  let(:test_runtimes){ Factory.project.test_runtimes }
  let(:runtimes){
    Hobson::Project::TestRuntimes::Runtimes.new(test_runtimes, 'spec:spec/something_spec.rb').tap{|runtimes|
      [10.2,11.5,9.8].each{|f| runtimes << f} # shove on runtimes
    }
  }
  subject{ runtimes }

  either_context do

    describe "#to_a" do
      it "should return a clone of @runtimes" do
        runtimes.to_a.object_id.should_not == runtimes.send(:runtimes).object_id
      end
      it "should return an array of it's cached runtimes" do
        runtimes.to_a.should == [10.2,11.5,9.8]
      end
    end

    describe "#each" do
      it "should loop through each runtime" do
        collected_runtimes = []
        runtimes.each{|r| collected_runtimes << r}
        collected_runtimes.should == [10.2,11.5,9.8]
      end
    end

    describe "#average" do
      it "should return the average of all known runtimes" do
        runtimes.average.should == 10.5
      end
    end

    describe "#<<" do
      it "should push the given runtime as a float onto the list of persisted runtimes" do
        runtimes << 12.7
        runtimes.to_a.should == [10.2,11.5,9.8,12.7]
      end
    end

  end

end
