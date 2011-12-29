# Logs the time a feature files takes to run to help in balancing a distrubuted build
#
# cucumber -r Hobson::Cucumber::Formatter
#
require 'cucumber'
require 'cucumber/formatter/io'
module Hobson
  module Cucumber
    class Formatter

      include ::Cucumber::Formatter::Io

      def initialize step_mother, path_or_io, options
        @io = ensure_io(path_or_io, "runtimes")
      end

      def before_feature feature
        raise "started twice!" unless @started_at.nil?
        @io.puts "PROGRESS:STARTED:#{feature.file}"
        @io.flush
        @started_at = Time.now
      end

      def after_feature(feature)
        duration = Time.now - @started_at
        status = feature.instance_variable_get(:@feature_elements).any?(&:failed?) ? 'FAIL' : 'PASS'
        @io.puts "PROGRESS:COMPLETED:#{feature.file}:#{status}:#{duration}"
        @io.flush
        @started_at = nil
      end

    end
  end
end
