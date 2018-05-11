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

      validate_option DateAdjuster::VALID_INPUT, :within, :at_least

      class << self
        def allows_at_least_option
          option :at_least, type: :string, instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
        end
      end

      def self.within_skip(type)
        define_method(:"within_check_#{type}?"){false}
      end

      def query(db)
        right_stream = apply_selectors(right_stream_query(db), function: rhs_function).from_self(alias: :r)
        ds = semi_or_inner_join(left_stream(db), right_stream, *[*join_columns, where_clause])

        ds = apply_selectors(ds, qualifier: :r)

        ds.from_self
      end

      def r_start_date
        Sequel[:r][:start_date]
      end

      def r_end_date
        Sequel[:r][:end_date]
      end

      def l_start_date
        Sequel[:l][:start_date]
      end

      def l_end_date
        Sequel[:l][:end_date]
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


      def apply_selectors(ds, opts = {})
        return ds unless include_rhs_columns
        ds = ds.select_remove(*include_rhs_columns).select_append(*(rhs_columns(opts))) if include_rhs_columns
        ds
      end

      def rhs_columns(opts)
        cols = include_rhs_columns
        return cols if opts.empty?
        cols = cols.map { |c| Sequel.function(opts[:function], c).as(c) } if opts[:function]
        cols = cols.map { |c| Sequel[opts[:qualifier]][c].as(c) } if opts[:qualifier]
        cols
      end

      def at_least_check?
        false
      end

      def inclusive?
        options[:inclusive]
      end

      def include_rhs_columns
        options[:include_rhs_columns] ? options[:include_rhs_columns].map(&:to_sym) : nil
      end

      def rhs_function
        nil
      end

      def use_inner_join?
        super || options[:include_rhs_columns]
      end
    end
  end
end


