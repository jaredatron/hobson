# Logs the time a feature files takes to run to help in balancing a distrubuted build
#
# cucumber -r Hobson::Formatters::Cucumber
#
require 'cucumber'
require 'cucumber/formatter/io'
require File.expand_path('../now', __FILE__)

module Hobson
  module Formatters
    class Cucumber

      include ::Cucumber::Formatter::Io

      def initialize step_mother, path_or_io, options
        @io = ensure_io(path_or_io, "hobson_status")
      end

      def before_feature feature
        raise "started twice!" unless @started_at.nil?
        @io.puts "TEST:#{feature.file}:START:#{Hobson::Formatters.now.to_f}"
        @io.flush
      end

      def after_feature(feature)
        status = feature.instance_variable_get(:@feature_elements).any?(&:failed?) ? 'FAIL' : 'PASS'
        @io.puts "TEST:#{feature.file}:COMPLETE:#{Hobson::Formatters.now.to_f}:#{status}"
        @io.flush
      end

    end
  end
end
