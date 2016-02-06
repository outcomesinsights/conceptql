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
        h = {}
        h[:left] = left.annotate(db) if left
        h[:right] = right.annotate(db) if right
        [options.merge(h), *arguments]
      end

      def create_upstreams
        @left = to_op(options[:left]) if options[:left]
        @right = to_op(options[:right])  if options[:right]
      end

      def validate
        super
        add_error("no left upstream") unless left
        add_error("no right upstream") unless right
      end
    end
  end
end
