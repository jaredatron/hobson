require 'spec_helper'

describe Hobson::CI::ProjectRef do

  # let(:project){ Factory.project }

  worker_context do

    describe "create" do
      before{
        @project = Factory.project('git://github.com/rails/rails.git')
      }
      context "when given a known project name" do
        it "should return a saved ProjectRef instance" do
          project_ref = Hobson::CI::ProjectRef.create('rails', 'master')
          project_ref.new_record?.should be_false
          Hobson::CI.project_refs.should == [project_ref]
        end
      end
      context "when given an unknown project name" do
        it "should raise and error" do
          lambda{ Hobson::CI::ProjectRef.create('fails', 'master') }.should raise_error
        end
      end
      context "when given invalid git ref" do
        it "should raise and error" do
          lambda{ Hobson::CI::ProjectRef.create('rails', nil) }.should raise_error
          lambda{ Hobson::CI::ProjectRef.create('rails', '') }.should raise_error
        end
      end
    end

    describe "find" do
      before{
        Factory.project('git://github.com/magic/donkies.git')
        @project_ref = Hobson::CI::ProjectRef.create('donkies', 'development')
      }
      context "when given a bad id" do
        it "should return nil" do
          Hobson::CI::ProjectRef.find('bad:id').should be_nil
        end
      end
      context "when given a good id" do
        it "should return a ProjectRef instance" do
          Hobson::CI::ProjectRef.find(@project_ref.id).should == @project_ref
        end
      end
    end

    describe "#test_runs" do
      let(:project_ref){ Factory.project_ref }
      context "when this project ref has no previous test_runs" do
        it "should return an empty array" do
          project_ref.test_runs.should == []
        end
      end
      context "when this project ref has previous test_runs" do
        it "should return an empty array" do
          project_ref.test_runs.should == []
        end
      end
    end

  end


end
