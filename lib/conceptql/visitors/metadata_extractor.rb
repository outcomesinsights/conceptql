module ConceptQL
  module Visitors
    class MetadataExtractor
      attr_reader :operators

      def initialize
        @operators = []
      end

      def visit(operator)
        operators << operator
      end

      def results
        {
          unique_operators:  operator_names.uniq.sort,
          operators_in_preorder: operator_names,
          codeset_only: codeset_only?,
          num_selection_nodes: num_selection_nodes,
          max_depth: max_depth
        }
      end

      def operator_names
        @operator_names ||= operators.map(&:op_name)
      end

      def codeset_only?
        return @codeset_only if defined?(@codeset_only)
        @codeset_only = operators.reject do |op|
          # We skip Unions because they don't count against codesets
          op.op_name == "union"
        end.map(&:class).map(&:basic_type).all? { |type| type == :selection }
      end

      def max_depth
        operators.reverse.each.with_object({}) do |op, counts|
          counts[op] = if op.all_upstreams.empty? 
                         1
                       else
                         counts.values_at(*op.all_upstreams).max + 1
                       end
        end.values.max
      end

      def num_selection_nodes
        operators.select { |op| op.upstreams.empty? }.length
      end
    end
  end
end
