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
      option :occurrences, type: :integer, desc: "Number of occurrences that must precede the event of interest, e.g. if you'd like the 4th event in a set of events, set occurrences to 3"

      validate_option DateAdjuster::VALID_INPUT, :within, :at_least
      validate_option /\A\d+\z/, :occurrences

      class << self
        def allows_at_least_option
          option :at_least, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
        end
      end

      def self.within_skip(type)
        define_method(:"within_check_#{type}?"){false}
      end

      def query(db)
        ds = db.from(left_stream(db))
               .join(right_stream(db), person_id: :person_id)
               .select_all(:l)

        ds = apply_where_clause(ds)

        ds = add_occurrences_condition(ds, occurrences_option)

        ds.from_self
      end

      def r_start_date
        return Sequel[:r][:start_date]
      end

      def r_end_date
        return Sequel[:r][:end_date]
      end

      def l_start_date
        return Sequel[:l][:start_date]
      end

      def l_end_date
        return Sequel[:l][:end_date]
      end

      def within_option
        options[:within]
      end

      def at_least_option
        options[:at_least]
      end

      def occurrences_option
        options[:occurrences]
      end

      def within_source_table
        Sequel[:r]
      end

      def within_start
        within_start = within_source_table[:start_date]
        if within_option
          within_start = adjust_date(within_option, within_start, true)
        end
        within_start
      end

      def within_end
        within_end = within_source_table[:end_date]
        if within_option
          within_end = adjust_date(within_option, within_end)
        end
        within_end
      end

      def adjust_date(adjustment, column, reverse = false)
        adjuster = DateAdjuster.new(self, adjustment)
        adjuster.adjust(column, reverse)
      end

      def add_occurrences_condition(ds, occurrences)
        return ds if occurrences.nil?

        occurrences_col = occurrences_column
        ds.distinct.from_self
          .select_append{row_number.function.over(:partition => :person_id, :order => occurrences_col).as(:occurrence)}
          .from_self
          .select(*dm.columns)
          .where{occurrence > occurrences.to_i}
      end

      def occurrences_column
        :start_date
      end

      def at_least_check?
        false
      end

      def inclusive?
        options[:inclusive]
      end
    end
  end
end


