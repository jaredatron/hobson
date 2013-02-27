require 'hobson'
require 'json'
require 'csv'

module Hobson
  module Metrics
    module FlakyTests
      extend self

      def report!(project)
        result = reduce_to_flaky_tests(
          tests_grouped_by_id_and_sha(
            finished_test_runs_for_project(project)
          )
        )
        Hobson.redis["metrics:#{project}:flaky_tests"] = result.to_json
        Hobson.redis["metrics:#{project}:flaky_tests:last_run"] = Time.now
        Hobson.files.create(
          key: "flaky_tests/#{Time.now.strftime("%Y-%m-%d_%H-%M")}.csv",
          content_type: 'text/csv',
          public: true,
          body: CSV.generate { |csv| result.each { |r| csv << r } },
        )
      end

      private

      def finished_test_runs_for_project(project)
        Hobson::Project.find(project).test_runs.find_all { |test_run| test_run.complete? }
      end

      def tests_grouped_by_id_and_sha(test_runs)
        result = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = [] } }
        test_runs.each do |test_run|
          test_run.tests.each do |test|
            result[test.id][test_run.sha] << test
          end
        end
        result
      end

      def reduce_to_flaky_tests(tests_hash)
        result = []
        tests_hash.each_pair do |test_id, shas_to_tests|
          flaky_failures = []
          shas_to_tests.each_pair do |sha, tests|
            next unless tests.find { |test| test.result == "PASS" }
            failures = tests.find_all { |test| test.result == "FAIL" || test.tries > 1 }
            next if failures.empty?
            flaky_failures.push(*failures)
          end
          last_flaky_failure = flaky_failures.max_by { |t| t.test_run.complete_at }
          last_flaky_failure_test_run_id = last_flaky_failure.test_run.id if last_flaky_failure
          result << [test_id, flaky_failures.count, last_flaky_failure_test_run_id]
        end
        result.sort_by!{ |test_id, count, test_run_id| count }.reverse!
      end
    end
  end
end
