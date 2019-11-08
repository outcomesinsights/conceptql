require_relative "../base"

module ConceptQL
  module Operators
    module Binary
      # Base class for all operators that take two streams, a left-hand and a right-hand
      class Base < Operators::Base
        option :left, type: :upstream
        option :right, type: :upstream
        validate_no_arguments
        validate_option Array, :left, :right
        validate_required_options :left, :right
        category "Filter by Comparing"
        basic_type :filter

        def upstreams
          [left]
        end

        def code_list(db)
          left.code_list(db) + right.code_list(db)
        end

        attr :left, :right

        private

        def complete_upstreams
          { left: left, right: right }
        end

        def join_columns(opts = {})
          join_columns_option.map{ |c| Sequel.expr([[Sequel[:l][c], Sequel[opts[:qualifier] || :r][c]]]) }
        end

        def join_columns_option
          (options[:join_columns] || []) + matching_columns
        end

        def annotate_values(db, opts = {})
          h = {}
          h[:left] = left.annotate(db, opts) if left
          h[:right] = right.annotate(db, opts) if right
          [options.merge(h), *arguments]
        end

        def create_upstreams
          @left = to_op(options[:left]) if options[:left].is_a?(Array)
          @right = to_op(options[:right])  if options[:right].is_a?(Array)
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
end
