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

      # The column lists are arrays of column names. The metadata has no list
      # type that the diagram editor can show, so they are declared as
      # :string, the type of the editor's plain text field.
      option :only_columns, type: :string,
                            instructions: "Compare only these columns. Cannot be used with Join Columns."
      option :except_columns, type: :string,
                              instructions: "Compare every column except these. Cannot be used with Join Columns."
      option :join_columns, type: :string,
                            instructions: "Compare only the person and these columns. Cannot be used with Only Columns or Except Columns."
      option :invert_match, type: :boolean,
                            instructions: "Keep the left hand records that have no matching right hand record."

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
        return (matching_columns + options[:join_columns].map(&:to_sym)).uniq if options[:join_columns]

        columns = dynamic_columns
        columns &= options[:only_columns].map(&:to_sym) if options[:only_columns]
        columns -= options[:except_columns].map(&:to_sym) if options[:except_columns]
        columns
      end

      def where_method(meth)
        return meth unless invert_match

        meth == :where ? :exclude : :where
      end

      def invert_match
        options[:invert_match]
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
        return unless options[:join_columns]

        conflicts = %i[only_columns except_columns].select { |name| options[name] }
        add_error("conflicting options", "join_columns", *conflicts.map(&:to_s)) unless conflicts.empty?
      end
    end
  end
end
