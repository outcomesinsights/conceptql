require_relative "../base"
require_relative "../../../date_adjuster"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        # Base class for all temporal operators
        #
        # Subclasses must implement the where_clause method which should probably return
        # a Sequel expression to use for filtering.
        class Base < Binary::Base
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

          def rhs_columns
            super | %i[start_date end_date]
          end

          def self.within_skip(type)
            define_method(:"within_check_#{type}?"){false}
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
            return unless v = options[:within]
            return if v.strip.empty?
            v
          end

          def at_least_option
            return unless v = options[:at_least]
            return if v.strip.empty?
            v
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

          def at_least_check?
            false
          end

          def inclusive?
            options[:inclusive]
          end
        end
      end
    end
  end
end


