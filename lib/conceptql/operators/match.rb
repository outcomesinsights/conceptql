# frozen_string_literal: true

require_relative "binary_operator_operator"

module ConceptQL
  module Operators
    # Compares the columns from #columns. Without options, that is every query
    # column, so a stream matched with itself keeps every record.
    class Match < BinaryOperatorOperator
      register __FILE__

      desc "Keeps left hand records that have the same values as a right hand side record. By default, every column is compared. only_columns or except_columns narrows that set, and join_columns compares only the person and the listed columns. Two NULL values count as the same value."
      default_query_columns

      # match reads only_columns, except_columns, join_columns and
      # invert_match, but does not declare them with `option`: only t_shank
      # gives them, and a declared option would appear in ConceptQL.metadata,
      # so the diagram editor would offer it (Ryan, 2026-10-26). Each column
      # list is an array of column names or a comma-separated string (see
      # Operator#column_names_option).

      # These columns identify a record and are never NULL, so match compares
      # them with =. It compares every other column NULL-safe: the value
      # columns are often NULL, and with = a NULL never equals a NULL.
      KEY_COLUMNS = %i[person_id criterion_id criterion_table criterion_domain start_date uuid window_id].freeze

      def query(db)
        rhs = right.evaluate(db)
        rhs = rhs.from_self.select_group(*columns)
        query = db.from(Sequel.as(left.evaluate(db), :l))

        join_check = columns.map { |column| column_check(column) }.inject(&:&)
        sub_select = rhs.from_self(alias: :r)
                        .select(1)
                        .where(join_check)

        query.send(where_method(:where), sub_select.exists).select_all(:l)
      end

      def columns
        @columns ||= determine_columns
      end

      # join_columns has the meaning that BinaryOperatorOperator gives it:
      # the person (and window) columns plus the listed columns.
      def determine_columns
        join_columns = column_names_option(:join_columns)
        return (matching_columns + join_columns).uniq if join_columns

        only_columns = column_names_option(:only_columns)
        except_columns = column_names_option(:except_columns)
        columns = dynamic_columns
        columns &= only_columns if only_columns
        columns -= except_columns if except_columns
        columns
      end

      def where_method(meth)
        return meth unless invert_match

        meth == :where ? :exclude : :where
      end

      # Existing statements give the string "true". The string "false" (in any
      # case, with any spaces around it) and a blank value do not invert.
      def invert_match
        text = options[:invert_match].to_s.strip
        !(text.empty? || text.casecmp?("false"))
      end

      private

      def column_check(column)
        left_column = Sequel[:l][column]
        right_column = Sequel[:r][column]
        return Sequel.expr([ [ left_column, right_column ] ]) if KEY_COLUMNS.include?(column)

        rdbms.null_safe_equal(left_column, right_column)
      end

      # join_columns sets the whole column set, so only_columns and
      # except_columns would have no effect next to it.
      def additional_validation(_db, _opts = {})
        return unless column_names_option(:join_columns)

        conflicts = %i[only_columns except_columns].select { |name| column_names_option(name) }
        add_error("conflicting options", "join_columns", *conflicts.map(&:to_s)) unless conflicts.empty?
      end
    end
  end
end
