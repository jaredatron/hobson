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
        @io = ensure_io(path_or_io, "hobson_status")
      end

      def before_feature feature
        raise "started twice!" unless @started_at.nil?
        @io.puts "TEST:#{feature.file}:START:#{Time.now.to_i}"
        @io.flush
      end

      def after_feature(feature)
        status = feature.instance_variable_get(:@feature_elements).any?(&:failed?) ? 'FAIL' : 'PASS'
        @io.puts "TEST:#{feature.file}:COMPLETE:#{Time.now.to_i}:#{status}"
        @io.flush
      end

    end
  end
end
