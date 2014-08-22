require_relative 'nodifier'
require 'active_support/core_ext/hash'

module ConceptQL
  class Tree
    attr :nodifier, :behavior
    def initialize(opts = {})
      @nodifier = opts.fetch(:nodifier, Nodifier.new)
      @behavior = opts.fetch(:behavior, nil)
    end

    def root(*queries)
      @root ||= traverse(queries.flatten.map(&:statement).flatten.map(&:deep_symbolize_keys))
    end

    private
    def traverse(obj)
      case obj
      when Hash
        if obj.keys.length > 1
          obj = Hash[obj.map { |key, value| [ key, traverse(value) ]}]
          return obj
        end
        type = obj.keys.first
        values = traverse(obj[type])
        obj = nodifier.create(type, values, self)
        obj.extend(behavior) if behavior
        obj
      when Array
        obj.map { |value| traverse(value) }
      else
        obj
      end
    end
  end
end
