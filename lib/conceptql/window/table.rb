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
        join_ds = remove_window_id(rhs)
          .select_append{row_number.function.over(order: rhs_columns).as(:window_id)}.as(:r)

        ds = remove_window_id(query)
          .from_self(alias: :l)

        op.rdbms.inner_join(ds, join_ds, expr)
          .select_all(:l)
          .select_append(Sequel[:r][:window_id])
          .from_self
      end

      def order_columns(op, rhs_columns)
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

        # When we're doing testing, we use a lot of constant expressions
        # for our columns.
        #
        # In 2014, someone decided to handle constant expressions thusly:
        # https://issues.apache.org/jira/browse/IMPALA-1354
        #
        # I've suffered myriad exceptions for 4 years because of that decision.
        #
        # Today, I discovered there is a recent change in Impala 3.1.0
        # that finally allows constant expressions:
        # https://issues.apache.org/jira/browse/IMPALA-6323
        #
        # But it is unlikely that Cloudera 6.1 will be available on our
        # production environment for years to come.  So it does me no good
        # today.
        #
        # Against all instinct, against all sense of decorum, against all I
        # know to be right, honest, and good, I have decided to detect when
        # tests are being run and make this software behave differently in those
        # circumstances.
        #
        # If we know we are running in test mode, we will make it so ALL
        # columns are no longer constant expressions.
        #
        # If we are not running in test mode, I will only apply this awful hack
        # to those columns that are most likely to be constant expressions.
        #
        # I already regret this decision.  I already apologize to my future
        # self and fellow future maintainers for what I have done on this day.
        #
        # I am so sorry for this ugly hack that I've implemented to work around
        # an ugly hack that someone else implemented 4 years prior.
        #
        # Though we may not be worthy of it, may we all be forgiven.
        if ENV["CONCEPTQL_IN_TEST_MODE"] == "I'm so sorry I did this"

          final_columns = final_columns.map { |c| c == :person_id ? c : op.rdbms.partition_fix(c) }
        end

        final_columns += fixed_static_columns
        final_columns
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

