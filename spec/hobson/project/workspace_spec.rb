require 'spec_helper'

describe Hobson::Project::Workspace do

  let(:workspace){ Factory.workspace }

  worker_context do

    before{
      @head = WorkerWorkingDirectory.example_project_current_sha
    }

    describe "#root" do
      subject { workspace.root }
      it { should == WorkerWorkingDirectory.example_project_path }
    end

    describe "#current_sha" do
      context "when the project has never been checked out before" do
        before{
          WorkerWorkingDirectory.example_project_path.rmtree
        }
        it "should return nil" do
          workspace.current_sha.should == @head
        end
      end
      context "when the project has been checked out before" do
        it "should return the sha of what is checked out now" do
          workspace.current_sha.should == @head
        end
      end
    end

    describe "#checkout!" do
      let(:sha1){ '921a8384933e59775e6ad86db5a02473c3e81468' }
      let(:sha2){ '6de51f394792768c1a0fe1383aa91bcedbf274a9' }
      let(:rev1){ 'origin/magic_branch' }
      let(:clutter){ workspace.root.join('clutter') }

      before{
        workspace.should_receive(:execute).with('git rev-parse HEAD'){ "#{sha1}\n" }.any_number_of_times
      }

      context "when given a sha that is different from the current sha" do
        it "should checkout and git clean" do
          workspace.should_receive(:execute).with("git rev-parse #{sha2}"){ "#{sha2}\n" }
          workspace.should_receive(:execute).once.with("git fetch --all && git checkout --quiet --force #{sha2} -- && git stash clear")
          workspace.should_receive(:execute).once.with("git clean -dfx")
          workspace.checkout! sha2
        end
      end
      context "when the current sha is the same as the given sha" do
        it "should not checkout the given sha but still git clean" do
          workspace.should_receive(:execute).with("git rev-parse #{sha1}"){ "#{sha1}\n" }
          workspace.should_not_receive(:execute).with("git fetch --all && git checkout --quiet --force #{sha1} -- && git stash clear")
          workspace.should_receive(:execute).once.with("git clean -dfx")
          workspace.checkout! sha1
        end
      end
      context "when given rev resolves to the current sha" do
        before{
          workspace.should_receive(:execute).with("git rev-parse #{rev1}"){ "#{sha1}\n"}
        }
        it "should not checkout the given sha but still git clean" do
          workspace.should_not_receive(:execute).with("git fetch --all && git checkout --quiet --force #{sha1} -- && git stash clear")
          workspace.should_receive(:execute).once.with("git clean -dfx")
          workspace.checkout! rev1
        end
      end
      context "when given rev does not resolve to the current sha" do
        before{
          workspace.should_receive(:execute).with("git rev-parse #{rev1}"){ "#{sha2}\n"}
        }
        it "should not checkout the given sha but still git clean" do
          workspace.should_receive(:execute).with("git fetch --all && git checkout --quiet --force #{sha2} -- && git stash clear")
          workspace.should_receive(:execute).once.with("git clean -dfx")
          workspace.checkout! rev1
        end
      end
    end

    describe "#prepare" do
      before{
        workspace.should_receive(:execute).with('git reset --hard && git clean -dfx').once
        workspace.should_receive(:execute).with('git reset').once
      }
      context "when we are not already prepapred" do
        before{
          workspace.root.join('log').rmdir if workspace.root.join('log').exist?
        }
        it "should prepare the workspace" do
          workspace.should_receive(:execute).once.with('git stash apply'){
            raise Hobson::Project::Workspace::ExecutionError, 'pretending this command failed'
          }
          workspace.should_receive(:execute).once.with("gem install bundler && bundle check || bundle install")
          workspace.should_receive(:execute).once.with('git add -Af && git stash && git stash apply')

          yielded = false
          workspace.prepare{ yielded = true }
          yielded.should be_true
          workspace.root.join('log').should exist
        end
      end
      context "when we are already prepapred" do
        before{
          workspace.should_receive(:execute).with('git stash apply'){ true }.once
        }
        it "should not prepare the workspace again" do
          workspace.should_not_receive(:execute).with("gem install bundler && bundle check || bundle install")
          workspace.should_not_receive(:execute).with('git add -Af && git stash && git stash apply')

          yielded = false
          workspace.prepare{ yielded = true }
          yielded.should be_false
        end
      end
    end

    describe "preventing needless redundant prepares" do

      let(:project){ Factory.project }
      let(:workspace){ project.workspace }
      let(:test_run1){
        sha = git_rev_parse('origin/integration_setup_hook_creates_untracked1')
        Factory.test_run(sha, project)
      }
      let(:test_run2){
        sha = git_rev_parse('origin/integration_setup_hook_creates_untracked2')
        Factory.test_run(sha, project)
      }
      # manually creating jobs allows us to skip the slow test_run.build! process
      let(:test_run1_job){ Hobson::Project::TestRun::Job.new(test_run1, 0) }
      let(:test_run2_job){ Hobson::Project::TestRun::Job.new(test_run2, 0) }

      def prepare_test_run1!
        test_run1_job.prepare_workspace!
      end

      def prepare_test_run2!
        test_run2_job.prepare_workspace!
      end

      def untracked1_file
        workspace.root.join('untracked1.txt')
      end

      def untracked2_file
        workspace.root.join('untracked2.txt')
      end

      it "doesnt prepare when it doesnt need to" do
        # we are not prepared
        ENV['HOBSON_SETUP_HOOK_RUN'] = "false"
        untracked1_file.should_not exist

        # first prepare
        prepare_test_run1!

        # should do a fill prepare
        ENV['HOBSON_SETUP_HOOK_RUN'].should == "true" # assert the project setup hook was called
        untracked1_file.should exist

        # mutate file in the workspace
        untracked1_file_contents = untracked1_file.read
        untracked1_file_contents.should_not == 'mutated file'
        untracked1_file.open('w'){|f| f.write('mutated file') }
        untracked1_file.read.should == 'mutated file'

        # reset the env variable set in this projects setup hook
        ENV['HOBSON_SETUP_HOOK_RUN'] = "false"

        # second prepare
        prepare_test_run1!

        # should NOT do a full prepare
        ENV['HOBSON_SETUP_HOOK_RUN'].should == "false" # assert the project setup hook was NOT called
        untracked1_file.should exist
        untracked1_file.read.should == untracked1_file_contents
      end

      it "prepares when it does need to" do
        test_run1 = Factory.test_run(git_rev_parse('origin/integration_setup_hook_creates_untracked1'))
        test_run2 = Factory.test_run(git_rev_parse('origin/integration_setup_hook_creates_untracked2'))

        # prepare test_run1
        prepare_test_run1!
        untracked1_file.should exist
        untracked2_file.should_not exist

        # prepare test_run2
        prepare_test_run2!
        untracked1_file.should_not exist
        untracked2_file.should exist

        # prepare test_run1
        prepare_test_run1!
        untracked1_file.should exist
        untracked2_file.should_not exist
      end

    end

  end

end

