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

      option :within, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :at_least, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :occurrences, type: :integer, desc: "Number of occurrences that must precede the event of interest, e.g. if you'd like the 4th event in a set of events, set occurrences to 3"

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


