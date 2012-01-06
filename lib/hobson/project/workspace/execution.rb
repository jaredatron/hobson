require 'childprocess'
require 'tempfile'

class Hobson::Project::Workspace::Execution

  attr_reader :process, :stdout, :stderr

  def initialize *args, &block
    @process = ChildProcess.new(*args)
    @stdout  = File.open((@process.io.stdout = tempfile).path)
    @stderr  = File.open((@process.io.stderr = tempfile).path)
  end

  def start &block
    block_given? ? block.call{ process.start } : process.start
  end

  def read_loop &block
    start unless process.send(:started?)
    while process.alive?
      read(&block)
      sleep 0.1
    end
    read(&block)
    exit_code
  end

  def read &block
    out, err = stdout.read, stderr.read
    yield(out, err) if block_given? && (out != "" || err != "")
    [out, err]
  end

  def exit_code
    process.exited?
    process.exit_code
  end

  private

  def tempfile
    Tempfile.new('hobson')
  end
  # delegate all public process methods that we dont have to process
  delegate(*((ChildProcess.new.public_methods - methods) + [{:to => :process}]))
  delegate :started?, :to => :process

end
