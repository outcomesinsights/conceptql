require_relative 'operator'
require 'facets/string/titlecase'

module ConceptQL
  module Operators
    # Base class for all operators that take two streams, a left-hand and a right-hand
    class BinaryOperatorOperator < Operator
      option :left, type: :upstream
      option :right, type: :upstream

      def upstreams
        [left]
      end

      def display_name
        self.class.name.split('::').last.snakecase.titlecase
      end

      attr :left, :right

      private

      def annotate_values(db)
        [options.merge(left: left.annotate(db), right: right.annotate(db))] + arguments
      end

      def create_upstreams
        @left = to_op(options[:left])
        @right = to_op(options[:right])
      end
    end
  end
end


