require_relative 'binary_operator_operator'
require_relative '../date_adjuster'

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

      validate_option DateAdjuster::VALID_INPUT, :within, :at_least
      validate_option /\A\d+\z/, :occurrences

      def self.within_skip(type)
        define_method(:"within_check_#{type}?"){false}
      end

      def query(db)
        ds = db.from(left_stream(db))
               .join(right_stream(db), l__person_id: :r__person_id)
               .where(where_clause)
               .select_all(:l)

        ds = add_option_conditions(ds)
        ds.from_self
      end

      def add_option_conditions(ds)
        if within = options[:within]
          ds = add_within_condition(ds, within)
        end

        if at_least = options[:at_least]
          ds = add_within_condition(ds, at_least, :exclude)
        end

        if occurrences = options[:occurrences]
          ds = add_occurrences_condition(ds, occurrences)
        end

        ds
      end

      def add_within_condition(ds, within, meth=:where)
        within = DateAdjuster.new(within)
        after = within.adjust(:r__start_date, true)
        before = within.adjust(:r__end_date)
        within_col = Sequel.expr(within_column)
        ds = ds.send(meth){within_col >= after} if within_check_after?
        ds = ds.send(meth){within_col <= before} if within_check_before?
        ds
      end

      def add_occurrences_condition(ds, occurrences)
        occurrences_col = occurrences_column
        ds.select_append{row_number{}.over(:partition => :r__person_id, :order => occurrences_col).as(:occurrence)}
          .from_self
          .select(*query_columns(ds))
          .where{occurrence > occurrences}
      end

      def within_column
        :l__start_date
      end

      def occurrences_column
        :r__start_date
      end

      def within_check_after?
        true
      end

      def within_check_before?
        true
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


