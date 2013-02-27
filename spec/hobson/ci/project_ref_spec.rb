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

    describe "run_tests!" do
      before{
        Factory.project('git://github.com/rails/rails.git')
        Hobson::CI::ProjectRef.create('rails', 'master')
      }
      define_method(:project_ref){
        Hobson::CI::ProjectRef.find('rails:master')
      }
      let(:test_runs){ [] }
      define_method(:assert_test_runs_are_equal!){
        project_ref.test_runs.should == 10.times.map{|i| test_runs[i]}
      }

      it "should store an index of the last 10 test runs" do
        assert_test_runs_are_equal!
        20.times{
          test_runs.unshift project_ref.run_tests!
          assert_test_runs_are_equal!
          # TODO assert test runs were deleted
        }
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

    %w{shas test_run_ids}.each{|attribute|
      describe "#{attribute}" do
        let(:project_ref) { Factory.project_ref }

        it "should return a #{Hobson::CI::ProjectRef::HISTORY_LENGTH} slot array" do
          result = project_ref.public_send(attribute.to_sym)
          result.should be_a Array
          result.length.should == Hobson::CI::ProjectRef::HISTORY_LENGTH
        end

        it "should memoize and only hit redis once" do
          project_ref.should_receive(:redis).once.and_return(stub(:lrange => []))
          project_ref.public_send(attribute.to_sym)
          project_ref.public_send(attribute.to_sym)
        end
      end
    }

    describe "#test_runs" do
      let(:project_ref){ Factory.project_ref }
      context "when this project ref has no previous test_runs" do
        it "should return an empty array" do
          project_ref.test_runs.should == Array.new(10)
        end
      end
      context "when this project ref has previous test_runs" do
        before{
          project_ref.stub(:current_sha){ '3dc35719edca885e5218c990077ac18fe2a566bf' }
          @test_runs = 2.times.map{ project_ref.run_tests! }
        }
        it "should return an empty array" do
          project_ref.test_runs.should == Array.new(10).zip(@test_runs.reverse).map(&:last)
        end
      end
    end

  end


end
