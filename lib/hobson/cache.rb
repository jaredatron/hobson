class Hobson::Cache

  @@simple_cache = {}

  class << self

    def read key
      @@simple_cache[key]
    end

    def write key, value
      @@simple_cache[key] = value
    end

    def delete key
      @@simple_cache.delete key
    end

    def has_key? key
      @@simple_cache.has_key? key
    end

    def fetch key, &block
      has_key?(key) ? read(key) : write(key, block.call)
    end

    def clear
      @@simple_cache = {}
    end

    def build_key model, modifier=nil
      key = model.respond_to?(:id) ? "#{model.class.name}-#{model.id}" : model
      key << "-#{modifier}" if modifier.present?
      key
    end

  end

end
