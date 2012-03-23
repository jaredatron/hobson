# Logs the time a feature files takes to run to help in balancing a distrubuted build
#
# cucumber -r Hobson::Formatters::Rspec
#
require 'rspec'
require 'rspec/core/formatters/base_formatter'
require File.expand_path('../now', __FILE__)

RSpec.configure do |config|

  get_spec = proc{ |this|
    this.class.file_path.split(':').first.split("#{::RSpec::Core::RubyProject.root}/").last
  }

  started_at = nil

  config.before :all do
    spec = get_spec.call(self)
    Hobson::Formatters::Rspec.puts "TEST:spec:#{spec}:START:#{Hobson::Formatters.now.to_f}"
  end

  config.after :all do
    spec = get_spec.call(self)

    status = begin
      self.class.descendant_filtered_examples \
        .map{ |t| t.metadata[:execution_result][:status] } \
        .any?{ |result| result == "failed" } ?
      'FAIL' : 'PASS'
    end

    Hobson::Formatters::Rspec.puts "TEST:spec:#{spec}:COMPLETE:#{Hobson::Formatters.now.to_f}:#{status}"
  end

end

module Hobson
  module Formatters
    class Rspec < ::RSpec::Core::Formatters::BaseFormatter

      def self.instances
        @@instances ||= []
      end

      def self.puts *args
        instances.each{|instance|
          instance.io.puts *args
          instance.io.flush
        }
      end

      attr_accessor :io

      def initialize io
        super
        @io = io
        self.class.instances << self
      end

    end
  end
end
