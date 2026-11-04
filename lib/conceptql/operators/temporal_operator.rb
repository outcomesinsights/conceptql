# frozen_string_literal: true

require_relative "binary_operator_operator"
require_relative "../date_adjuster"

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

      option :within, type: :string,
                      instructions: 'Enter a positive number followed by "d", "w", "m" or "y" for days, weeks, months or years. Example: 30d.',
                      meaning: "A date adjustment, such as 30d, 2m or 1y-3d, that lets the compared dates be up to this amount apart. Each temporal operator applies it to its own comparison. Use a positive amount."

      # The temporal operators read join_columns through
      # BinaryOperatorOperator#join_columns_option, but do not declare it with
      # `option`: only t_shank gives it, and a declared option would appear in
      # ConceptQL.metadata, so the diagram editor would offer it (Ryan,
      # 2026-10-26).

      validate_option DateAdjuster::VALID_INPUT, :within, :at_least

      class << self
        def allows_at_least_option
          option :at_least, type: :string,
                            instructions: 'Enter a positive number followed by "d", "w", "m" or "y" for days, weeks, months or years. Example: 30d.',
                            meaning: "A date adjustment, such as 7d or 1w, that sets the smallest gap between the compared dates. The gap must be larger than this amount. Use a positive amount."
        end
      end

      def self.within_skip(type)
        define_method(:"within_check_#{type}?") { false }
      end

      def query(db)
        right_stream = apply_selectors(right_stream_query(db), function: rhs_function).from_self(alias: :r)
        ds = semi_or_inner_join(left_stream(db), right_stream, *join_columns, where_clause)

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
        return unless (v = options[:within])
        return if v.strip.empty?

        v
      end

      def at_least_option
        return unless (v = options[:at_least])
        return if v.strip.empty?

        v
      end

      def within_source_table
        Sequel[:r]
      end

      def within_start
        within_start = within_source_table[:start_date]
        within_start = adjust_date(within_option, within_start, true) if within_option
        within_start
      end

      def within_end
        within_end = within_source_table[:end_date]
        within_end = adjust_date(within_option, within_end) if within_option
        within_end
      end

      def adjust_date(adjustment, column, reverse = false)
        adjuster = DateAdjuster.new(self, adjustment)
        adjuster.adjust(column, reverse)
      end

      def apply_selectors(ds, opts = {})
        return ds unless include_rhs_columns

        # A dataset without a select list reads an upstream, so it has the
        # scope's columns. Name them: select_remove would ask the database
        # for them, and the CTE of a labeled upstream does not exist while
        # the SQL is built (bead conceptql-6k8).
        ds = ds.select(*dynamic_columns) if ds.opts[:select].blank?
        ds.select_remove(*include_rhs_columns).select_append(*rhs_columns(opts))
      end

      def rhs_columns(opts)
        cols = include_rhs_columns
        return cols if opts.empty?

        cols = cols.map { |c| Sequel.function(opts[:function], c).as(c) } if opts[:function]
        cols = cols.map { |c| Sequel[opts[:qualifier]][c].as(c) } if opts[:qualifier]
        cols
      end

      def include_rhs_columns
        options[:include_rhs_columns]&.map(&:to_sym)
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
