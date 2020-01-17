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

        def query(db)
          ds = semi_or_inner_join(
            lhs(db),
            rhs(db, table_alias: :r),
            *([*join_clause, where_clause]).compact
          )
          prepare_columns(ds)
        end

        def upstreams
          [left]
        end

        def code_list(db)
          left.code_list(db) + right.code_list(db)
        end

        def required_columns=(cols)
          raise "required_columns got invalid column: #{cols.inspect}" unless cols.all? { |c| c.is_a?(Symbol) }
          @required_columns = cols
          left.required_columns = required_columns_for_upstream if left
          right.required_columns = rhs_columns if right
        end

        def required_columns
          super | join_columns
        end

        attr :left, :right

        private

        def lhs_columns
          join_columns | scope.query_columns
        end

        def rhs_columns
          cols = join_columns | include_rhs_columns | (required_columns - scope.query_columns)
          cols |= rdbms.uuid_columns
        end

        def complete_upstreams
          {left: left, right: right}
        end

        def join_clause(opts = {})
          join_columns.map{ |c| Sequel.expr([[Sequel[:l][c], Sequel[opts[:qualifier] || :r][c]]]) }
        end

        def join_columns
          (options[:join_columns] || []) | matching_columns
        end

        def prepare_columns(ds, opts = {})
          ds = ds.auto_qualify(:l)
          ds = ds.auto_columns(replacement_columns) if respond_to?(:replacement_columns)
          rhs_qualifier = Sequel[opts.fetch(:qualifier, :r)]
          rhs_cols = (include_rhs_columns || []).map do |rhs_column_name|
            rhs_column = rhs_qualifier[rhs_column_name]
            rhs_column = Sequel.function(opts[:function], rhs_column) if opts[:function]
            [rhs_column_name, rhs_column]
          end.to_h
          ds.auto_columns(rhs_cols) 
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

        def left_stream(db, opts = {})
          left_stream_query(db, opts)
        end

        def left_stream_query(db, opts = {})
          left.evaluate(db, {alias: :l}.merge(opts))
        end

        def right_stream(db, opts = {})
          right_stream_query(db, opts).as(:r)
        end

        def right_stream_query(db, opts = {})
          right.evaluate(db, {alias: :r}.merge(opts))
        end

        def lhs(db, opts = {})
          left_stream_query(db, opts)
        end
 
        def rhs(db, opts = {})
          right_stream_query(db, opts)
        end

        def include_rhs_columns
          options[:include_rhs_columns] ? options[:include_rhs_columns].map(&:to_sym) : []
        end

        def use_inner_join?
          super || !(include_rhs_columns.empty?)
        end
     end
    end
  end
end
