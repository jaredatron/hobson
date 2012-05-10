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
        @step_mother = step_mother
        @io = ensure_io(path_or_io, "hobson_status")
      end

      def before_feature_element feature_element
        @started_at = Hobson::Formatters.now.to_f
        true
      end

      def scenario_name keyword, name, file_colon_line, source_indent
        @scenario_name = name
        @io.puts "TEST:scenario:#{@scenario_name}:START:#{@started_at}"
        @io.flush
      end

      def after_feature_element feature_element
        ended_at = Hobson::Formatters.now.to_f
        begin
          # this is wonky but because of scenario outlines some "feature elements" actaully
          # represent more then on "scenario" so we collect them all here
          scenarios = @step_mother.results.scenarios.find_all{|scenario|
            scenario = scenario.scenario_outline if scenario.is_a? ::Cucumber::Ast::OutlineTable::ExampleRow
            scenario.title == feature_element.title
          }
          # and if any of them did not pass the whole thing is considered a fail
          result = scenarios.any?{|scenario| scenario.status != :passed} ? 'FAIL' : 'PASS'
          @io.puts "TEST:scenario:#{@scenario_name}:COMPLETE:#{ended_at}:#{result}"
        rescue Exception => e
          @io.puts "TEST:scenario:#{@scenario_name}:COMPLETE:#{ended_at}:ERROR" rescue nil
          raise
        ensure
          @io.flush
          @scenario_name = @started_at = nil
        end
      end

    end
  end
end
