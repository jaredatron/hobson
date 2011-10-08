require 'spec_helper'

describe Hobson::Project::Workspace do

  subject{ Factory.workspace }
  alias_method :workspace, :subject

  client_context do

    # describe "#root" do
    #   subject { Factory.workspace.root }
    #   it { should == ClientWorkingDirectory.path }
    # end

  end

  worker_context do

    describe "#root" do
      subject { Factory.workspace.root }
      it { should == WorkerWorkingDirectory.example_project_path }
    end

  end

  either_context do

  end

end

