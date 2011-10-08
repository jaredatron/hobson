module Hobson::Landmarks

  def self.extended base
    base.send :include, InstanceMethods
  end

  module InstanceMethods

    def landmarks
      self.class.landmarks
    end

  end

  attr_reader :landmarks

  def landmark *landmarks
    @landmarks ||= []
    @landmarks += landmarks
    landmarks.each do |landmark|
      landmark = landmark.to_s.gsub(' ','_')
      class_eval <<-RUBY, __FILE__, __LINE__

        def #{landmark}!
          self["#{landmark}_at"] ||= Time.now
        end

        def #{landmark}_at
          self["#{landmark}_at"]
        end

        def #{landmark}?
          self.#{landmark}_at.present?
        end

      RUBY
    end
  end

end
