# frozen_string_literal: true

require_relative 'base'

module ConceptQL
  module Window
    # Provides a scope window based on the ConceptQL result set of another table
    class Table < Base
      def call(op, query, options = {})
        l_table = Sequel[:l]
        r_table = Sequel[:r]
        r_start_date = apply_adjustments(op, r_table[:start_date], adjust_start)
        r_end_date = apply_adjustments(op, r_table[:end_date], adjust_end)

        exprs = []
        exprs << Sequel.expr(l_table[:person_id] => r_table[:person_id])

        query = Sequel[query] if query.is_a?(Symbol)

        unless options[:timeless]
          exprs << (r_start_date <= l_table[event_start_date_column])
          exprs << (l_table[event_end_date_column] <= r_end_date)
        end
        expr = exprs.inject(&:&)

        order_cols = order_columns(op)

        rhs = query.db[get_table_window(query)]

        unless opts[:precalculated_window_id]
          rhs = remove_window_id(rhs)
          rhs = rhs
                .select_group(:person_id, :start_date, :end_date)
                .select_append do
                  row_number.function.over(order: order_cols)
                            .as(:window_id)
                end
        end

        rhs = rhs.as(:r)

        remove_window_id(query)
          .from_self(alias: :l)
          .join(rhs, expr)
          .select_all(:l)
          .select_append(r_table[:window_id])
          .from_self
      end

      def order_columns(op)
        # Hack until Cloudera 6.1
        %i[person_id start_date end_date].map do |c|
          c == :person_id ? c : op.rdbms.partition_fix(c)
        end
      end

      def remove_window_id(ds)
        if (cols = selected_columns(ds)) && cols.all? { |s| s.is_a?(Symbol) }
          ds.select(*(cols - [:window_id]))
        else
          ds.select_remove(:window_id)
        end
      end

      def selected_columns(ds)
        opts = ds.opts
        if (select = opts[:select])
          select
        elsif (from = opts[:from].first).is_a?(Sequel::Dataset)
          selected_columns(from)
        end
      end

      def get_table_window(_query)
        case table_window
        when Array
          cdb.query(table_window).query(force_temp_tables: false)
        when String
          tables = table_window.split('.')
          tables.length == 2 ? Sequel.qualify(*tables) : Sequel.identifier(table_window)
        when Symbol
          Sequel[table_window]
        else
          table_window
        end
      end

      def apply_adjustments(op, column, adjustment)
        return column unless adjustment

        DateAdjuster.new(op, adjustment).adjust(column)
      end

      def table_window
        opts[:window_table]
      end

      def cdb
        opts[:cdb]
      end

      def adjust_start
        opts[:adjust_window_start]
      end

      def adjust_end
        opts[:adjust_window_end]
      end
    end
  end
end
