require 'facets/array/extract_options'
require 'facets/hash/deep_rekey'
require 'facets/hash/update_values'

module ConceptQL
  class Converter
    def convert(statement)
      traverse(statement).to_list_syntax
    end

  private
    class Operator
      attr :type, :values, :options
      def initialize(type, *values)
        @type, @values = type, values.flatten
        @options = @values.extract_options!.deep_rekey
        @values = @values
      end

      def args
        values.select { |s| !s.is_a?(Operator) }
      end

      def upstreams
        values.select { |s| s.is_a?(Operator) }
      end

      def converted_options
        options.update_values do |value|
          if value.is_a?(Operator)
            value.to_list_syntax
          else
            value
          end
        end
      end

      def to_list_syntax
        stmt = [type]
        stmt += args unless args.empty?
        stmt += upstreams.map(&:to_list_syntax) unless upstreams.empty?
        stmt << converted_options unless options.empty?
        stmt
      end
    end

    def traverse(obj)
      case obj
      when Hash
        if obj.keys.length > 1
          obj = Hash[obj.map { |key, value| [ key, traverse(value) ]}]
          return obj
        end
        type = obj.keys.first
        values = traverse(obj[type])
        obj = Operator.new(type, values)
        obj
      when Array
        obj.map { |value| traverse(value) }
      else
        obj
      end
    end
  end
end
