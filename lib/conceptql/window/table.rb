module ConceptQL
  module Window
    class Table
      attr :table_window, :cdb, :adjust_start, :adjust_end

      def initialize(table_window, cdb, adjust_start, adjust_end)
        @cdb = cdb
        @table_window = table_window
        @adjust_start = adjust_start
        @adjust_end = adjust_end
      end

      def call(op, query, opts = {})
        start_date = apply_adjustments(op, Sequel[:r][:start_date], adjust_start)
        end_date = apply_adjustments(op, Sequel[:r][:end_date], adjust_end)

        exprs = []
        exprs << Sequel.expr({ Sequel[:l][:person_id] => Sequel[:r][:person_id] })

        query = Sequel[query] if query.is_a?(Symbol)
        table = get_table_window(table_window, query)
        table = Sequel[table] if table.is_a?(Symbol)

        unless opts[:timeless]
          exprs << (start_date <= Sequel[:l][:start_date])
          exprs << (Sequel[:l][:end_date] <= end_date)
        end
        expr = exprs.inject(&:&)

        rhs = query.db[table]
        rhs_columns = order_columns(op, rhs.columns)
        remove_window_id(query)
          .from_self(alias: :l)
          .join(remove_window_id(rhs)
              .select_group(:person_id, :start_date, :end_date)
              .select_append{row_number.function.over(order: rhs_columns).as(:window_id)}.as(:r),
            expr)
        .select_all(:l)
        .select_append(Sequel[:r][:window_id])
        .from_self
      end

      def order_columns(op, rhs_columns)
=begin
        possibly_static_columns = rhs_columns & ConceptQL::Rdbms::Impala::POSSIBLY_STATIC_COLUMNS
        fixed_static_columns = possibly_static_columns.map { |c| op.rdbms.partition_fix(c) }
        final_columns = (rhs_columns - possibly_static_columns)

        if ENV["CONCEPTQL_SORT_TEMP_TABLES"] == "true"
          # It's possible we've already sorted the tables a bit, so let's try
          # to use that existing order and then order by everything else after
          already_ordered_columns = rhs_columns & ConceptQL::Rdbms::Impala::SORT_BY_COLUMNS
          final_columns = already_ordered_columns
          final_columns += (rhs_columns - already_ordered_columns) - possibly_static_columns
        end

        if ENV["CONCEPTQL_IN_TEST_MODE"] ==  "I'm so sorry I did this"
          final_columns = final_columns.map { |c| c == :person_id ? c : op.rdbms.partition_fix(c) }
        end

        final_columns += fixed_static_columns
        final_columns
=end
        # Hack until Cloudera 6.1
        %i(person_id start_date end_date).map { |c| c == :person_id ? c : op.rdbms.partition_fix(c) }
      end

      def remove_window_id(ds)
        if (cols = selected_columns(ds)) && cols.all?{|s| s.is_a?(Symbol)}
          ds.select(*(cols - [:window_id]))
        else
          ds.select_remove(:window_id)
        end
      end

      def selected_columns(ds)
        if ds.opts[:select]
          ds.opts[:select]
        elsif ds.opts[:from].first.is_a?(Sequel::Dataset)
          selected_columns(ds.opts[:from].first)
        end
      end

      def get_table_window(table_window, query)
        case table_window
        when Array
          cdb.query(table_window).query
        when String
          tables = table_window.split(".")
          if tables.length == 2
            Sequel.qualify(*tables)
          else
            Sequel.identifier(table_window)
          end
        else
          table_window
        end
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment
        DateAdjuster.new(op, adjustment).adjust(column)
      end
    end
  end
end

