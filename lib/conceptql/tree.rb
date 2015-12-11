require_relative 'nodifier'
require_relative 'converter'
require_relative 'scope'
require 'facets/hash/deep_rekey'
require 'facets/array/recurse'

module ConceptQL
  # Tree is used to walk through a ConceptQL statement, instantiate
  # all operators, and then provide access to the root operator
  class Tree
    attr :nodifier, :behavior, :defined, :opts, :temp_tables, :scope
    def initialize(opts = {})
      @nodifier = opts.fetch(:nodifier, Nodifier.new)
      @behavior = opts.fetch(:behavior, nil)
      @defined = {}
      @temp_tables = {}
      @opts = {}
      @scope = opts.fetch(:scope, Scope.new)
    end

    def root(query)
      @root ||= start_traverse(query.statement)
    end

    private

    def start_traverse(stmt)
      case stmt
      when Hash
        traverse(converter.convert(stmt))
      when Array
        traverse(stmt)
      end
    end

    def traverse(stmt)
      stmt.recurse(Array, Hash) do |arr_or_hash|
        if arr_or_hash.is_a?(Array)
          type = arr_or_hash.shift
          obj = nodifier.create(scope, type, *arr_or_hash)
          obj.extend(behavior) if behavior
          obj
        else
          arr_or_hash
        end
      end
    end

    def converter
      @converter ||= Converter.new
    end
  end
end
