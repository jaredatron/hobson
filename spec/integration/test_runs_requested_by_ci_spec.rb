require 'spec_helper'

describe "undefined scenarios should fail spec" do

  worker_context do

    context "when ci requests a test run and you want to rerun it" do

      before{
        Hobson::Project.create('git://github.com/rails/rails.git')
        Hobson::CI::ProjectRef.create('rails', 'master')
      }

      def project
        Hobson::Project.find('rails')
      end

      def ci_project_ref
        Hobson::CI::ProjectRef.find('rails:master')
      end

      def project_test_runs
        project.test_runs
      end

      def ci_project_ref_test_runs
        ci_project_ref.test_runs.compact
      end

      it "should inform rerun the sha through the ci project ref" do
        test_run0 = project.run_tests! :sha => '5ccbcce91fb76a6969ff80748195d02455ad6d0f', :requestor => 'the test suite'
        test_run1 = ci_project_ref.run_tests! 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'

        test_runs = project_test_runs
        test_runs.size.should == 2
        test_runs[0].id.should == test_run1.id
        test_runs[0].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'
        test_runs[1].id.should == test_run0.id
        test_runs[1].sha.should == '5ccbcce91fb76a6969ff80748195d02455ad6d0f'

        test_runs = ci_project_ref_test_runs
        test_runs.size.should == 1
        test_runs[0].id.should == test_run1.id
        test_runs[0].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'

        test_run2 = test_run0.rerun!
        test_run3 = test_run1.rerun!

        test_runs = project_test_runs
        test_runs.size.should == 4
        test_runs[0].id.should == test_run3.id
        test_runs[0].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'
        test_runs[1].id.should == test_run2.id
        test_runs[1].sha.should == '5ccbcce91fb76a6969ff80748195d02455ad6d0f'
        test_runs[2].id.should == test_run1.id
        test_runs[2].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'
        test_runs[3].id.should == test_run0.id
        test_runs[3].sha.should == '5ccbcce91fb76a6969ff80748195d02455ad6d0f'

        test_runs = ci_project_ref_test_runs
        test_runs.size.should == 2
        test_runs[0].id.should == test_run3.id
        test_runs[0].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'
        test_runs[1].id.should == test_run1.id
        test_runs[1].sha.should == 'cdb74c4bf746394c46364d31bb23afcdc87d49a8'
      end
    end

  end

end
