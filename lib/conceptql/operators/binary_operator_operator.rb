require_relative 'operator'
require 'facets/string/titlecase'

module ConceptQL
  module Operators
    # Base class for all operators that take two streams, a left-hand and a right-hand
    class BinaryOperatorOperator < Operator
      option :left, type: :upstream
      option :right, type: :upstream
      validate_no_arguments
      validate_option Array, :left, :right
      validate_required_options :left, :right
      basic_type :filter

      def upstreams
        [left]
      end

      def display_name
        self.class.name.split('::').last.snakecase.titlecase
      end

      attr :left, :right

      private

      def annotate_values(db)
        h = {}
        h[:left] = left.annotate(db) if left
        h[:right] = right.annotate(db) if right
        [options.merge(h), *arguments]
      end

      def create_upstreams
        @left = to_op(options[:left]) if options[:left].is_a?(Array)
        @right = to_op(options[:right])  if options[:right].is_a?(Array)
      end
    end
  end
end
