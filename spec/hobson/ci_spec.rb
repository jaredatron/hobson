require 'spec_helper'

describe Hobson::Project do

  subject { Factory.project }
  alias_method :project, :subject

  worker_context do

  end

end
