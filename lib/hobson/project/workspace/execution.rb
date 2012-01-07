# require 'childprocess'
# require 'tempfile'

# class Hobson::Project::Workspace::Execution

#   attr_reader :process, :stdout, :stderr, :stdout_file, :stderr_file

#   def initialize *args, &block
#     @process     = ChildProcess.new(*args)
#     @stdout      = ""
#     @stderr      = ""
#     @stdout_file = File.open((@process.io.stdout = tempfile).path)
#     @stderr_file = File.open((@process.io.stderr = tempfile).path)
#     read_loop(&block) if block_given?
#   end

#   def start
#     process.start unless started?
#   end

#   def read_loop &block
#     start unless started?
#     while process.alive?
#       read(&block)
#       sleep 0.1
#     end
#     read(&block)
#     self
#   end

#   def read &block
#     out, err = @stdout_file.read, @stderr_file.read
#     @stdout += out
#     @stderr += err
#     yield out, err if block_given? && (out != "" || err != "")
#     [out, err]
#   end

#   def exit_code
#     process.exited?
#     process.exit_code
#   end

#   def success?
#     exit_code == 0 if exited?
#   end

#   def failed?
#     !success?
#   end

#   def args
#     process.instance_variable_get(:@args)
#   end

#   def inspect
#     "#<#{self.class} #{args.inspect}>"
#   end
#   alias_method :to_s, :inspect

#   private

#   def tempfile
#     Tempfile.new('hobson')
#   end

#   # delegate all public process methods that we dont have to process
#   delegate(*((ChildProcess.new.public_methods - instance_methods) + [{:to => :process}]))
#   delegate :started?, :to => :process

# end
