module Contexts

  # Hobson can be run in two modes, the client and worker
  # these methods make it easy to write tests for Hobson
  # in each context

  def client_context &block
    context "when run from a client" do
      let(:context){ ClientWorkingDirectory }
      before{
        context.reset!
        Dir.chdir context.path
        Hobson.logger.info "logging in the #{context} context"
      }
      class_eval(&block)
    end
  end

  def worker_context &block
    context "when run from a worker" do
      let(:context){ WorkerWorkingDirectory }
      before{
        context.reset!
        Dir.chdir context.path
        Hobson.logger.info "logging in the #{context} context"
      }
      class_eval(&block)
    end
  end

  def either_context &block
    client_context &block
    worker_context &block
  end

end
