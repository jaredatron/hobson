# require 'spec_helper'

describe Hobson::Project::Workspace do

  subject{ Factory.workspace }
  alias_method :workspace, :subject

  worker_context do

    describe "#root" do
      subject { Factory.workspace.root }
      it { should == WorkerWorkingDirectory.example_project_path }
    end

  end

end

