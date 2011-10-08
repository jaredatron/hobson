module Hobson::Steps

  # def self.extended base
  #   base.send :include, InstanceMethods
  # end

  # module InstanceMethods

  #   def steps
  #     self.class.steps
  #   end

  #   def step
  #     @step ||= redis['step']
  #   end

  #   def step_times
  #     times = redis.hgetall('at')
  #     steps.map{|step|
  #       time = times[step]
  #       time.present? ? Time.parse(time) : nil
  #     }
  #   end

  # end

  # def steps *steps
  #   return @steps.clone if @steps.present?
  #   @steps = steps

  #   steps.each{ |step|
  #     method = step.gsub(' ','_')

  #     class_eval <<-RUBY, __FILE__, __LINE__

  #       def #{method}!
  #         return false if #{method}_at.present?
  #         logger.info "STEP: #{step}"
  #         redis.hset('at', '#{step}', Time.now)
  #         @step = redis['step'] = '#{step}'
  #       end

  #       def #{method}?
  #         self.step == '#{step}'
  #       end

  #       def #{method}_at
  #         step_times[steps.index('#{step}')]
  #       end

  #     RUBY
  #   }
  # end

end
