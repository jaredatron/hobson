module Contexts

  # Hobson can be run in two modes, the client and worker
  # these methods make it easy to write tests for Hobson
  # in each context

  def client_context &block
    context "when run from a client" do
      before{
        ClientWorkingDirectory.reset!
        Dir.chdir ClientWorkingDirectory.path
        Hobson.logger.info "logging in the client context"
      }
      class_eval(&block)
    end
  end

  def worker_context &block
    context "when run from a worker" do
      before{
        WorkerWorkingDirectory.reset!
        Dir.chdir WorkerWorkingDirectory.path
        Hobson.logger.info "logging in the worker context"
      }
      class_eval(&block)
    end
  end

  def either_context &block
    client_context &block
    worker_context &block
  end

end
