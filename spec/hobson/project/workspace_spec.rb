require 'spec_helper'

describe Hobson::Project::Workspace do

  subject{ Factory.workspace }
  alias_method :workspace, :subject

  worker_context do

    describe "#root" do
      subject { Factory.workspace.root }
      it { should == WorkerWorkingDirectory.example_project_path }
    end

    describe "#tests" do
      subject { Factory.workspace.tests.sort }
      it {
        should == %w[
          features/a.feature
          features/b.feature
          features/c.feature
          features/d.feature
          spec/a_spec.rb
          spec/b_spec.rb
          spec/c_spec.rb
          spec/d_spec.rb
        ].sort
      }

    end

  end

end

