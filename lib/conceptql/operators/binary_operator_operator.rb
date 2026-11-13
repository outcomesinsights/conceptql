# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    # Base class for all operators that take two streams, a left-hand and a right-hand
    class BinaryOperatorOperator < Operator
      option :left, type: :upstream,
                    meaning: "The left-hand stream. The operator compares these results with the right-hand stream and passes on the ones that meet its condition."
      option :right, type: :upstream,
                     meaning: "The right-hand stream. The operator compares the left-hand results with these results and does not pass them on."
      # The operands are the left and right options. A positional upstream
      # would be ignored, so it is an error (Ryan ruled 2026-11-03).
      validate_no_upstreams
      validate_no_arguments
      validate_option Array, :left, :right
      validate_required_options :left, :right
      category "Filter by Comparing"
      diagram_base :filter

      def upstreams
        [ left ]
      end

      def code_list(db)
        left.code_list(db) + right.code_list(db)
      end

      attr_reader :left, :right

      # events_per_patient and multiple_vocabularies come from Operator, which
      # reads upstreams.first, the left. A missing left gives :multiple and
      # false, the values of an operator with no upstream.

      # A missing operand, or one that is not an array, is nil. The
      # validations report it, and the walk skips it.
      def accept(visitor, opts = {})
        visitor.visit(self)
        left&.accept(visitor, opts)
        right&.accept(visitor, opts) unless opts[:avoid_rhs]
      end

      def all_upstreams
        [ left, right ].compact
      end

      private

      def pp_upstreams
        { left: left, right: right }
      end

      def join_columns(opts = {})
        join_columns_option.map { |c| Sequel.expr([ [ Sequel[:l][c], Sequel[opts[:qualifier] || :r][c] ] ]) }
      end

      def join_columns_option
        (column_names_option(:join_columns) || []) + matching_columns
      end

      def annotate_values(db, opts = {})
        h = {}
        h[:left] = left.annotate(db, opts) if left
        h[:right] = right.annotate(db, opts) if right
        [ options.merge(h), *arguments ]
      end

      def create_upstreams
        @left = to_op(options[:left]) if options[:left].is_a?(Array)
        @right = to_op(options[:right])  if options[:right].is_a?(Array)
      end

      # create_upstreams leaves the positional upstreams as statements
      def upstream_operator_names
        @upstreams.map { |stmt| stmt.is_a?(Operator) ? stmt.op_name : stmt.first }
      end

      def left_stream(db)
        left_stream_query(db)
      end

      def left_stream_query(db)
        left.evaluate(db).from_self(alias: :l)
      end

      def right_stream(db)
        right_stream_query(db).as(:r)
      end

      def right_stream_query(db)
        right.evaluate(db).from_self(alias: :r)
      end
    end
  end
end
