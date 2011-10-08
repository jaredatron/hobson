# class << Hobson::Project::TestRun

#   # def ids
#   #   Hobson.redis.keys.inject([]){|test_run_ids, redis_key|
#   #     if redis_key =~ /^TestRun:([\w-]+)$/
#   #       test_run_ids << $1
#   #     end
#   #     test_run_ids
#   #   }.sort
#   # end

#   # def get id
#   #   new.tap{|test_run| test_run.instance_variable_set(:@id, id) }
#   # end

#   # def all
#   #   ids.map{|id| get id }
#   # end

#   def create! project_name=current_project_name, sha=current_sha
#     test_run = Hobson::Project::TestRun.new
#     test_run.project_name = project_name
#     test_run.sha = sha
#     test_run
#   end

#   private

#   def current_project_name
#     `git config --get remote.origin.url`.scan(%r{/([^/]+)\.git}).try(:first).try(:first) or
#       raise "unable to parse project name from remote origin url"
#   end

#   def current_sha
#     `git rev-parse HEAD`.chomp or raise "unable to get current sha"
#     # TODO make sure the current sha is pushed to origin
#   end

# end
