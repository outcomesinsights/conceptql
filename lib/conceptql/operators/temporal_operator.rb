require_relative 'binary_operator_operator'

module ConceptQL
  module Operators
    # Base class for all temporal operators
    #
    # Subclasses must implement the where_clause method which should probably return
    # a Sequel expression to use for filtering.
    class TemporalOperator < BinaryOperatorOperator
      reset_categories
      category "Filter by Comparing"
      default_query_columns

      option :within, type: :string
      option :at_least, type: :string
      option :occurrences, type: :integer

      validate_option /\A#{Regexp.union([/START/i, /END/i, /\d{4}-\d{2}-\d{2}/, /([-+]?\d+[dmy])+/])}\z/, :within, :at_least
      validate_option /\A\d+\Z/, :occurrences

      def query(db)
        db.from(db.from(left_stream(db))
                  .join(right_stream(db), l__person_id: :r__person_id)
                  .where(where_clause)
                  .select_all(:l))
      end

      def inclusive?
        options[:inclusive]
      end

      def left_stream(db)
        Sequel.expr(left.evaluate(db).from_self).as(:l)
      end

      def right_stream(db)
        Sequel.expr(right.evaluate(db).from_self).as(:r)
      end
    end
  end
end


