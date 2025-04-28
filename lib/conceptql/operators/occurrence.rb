# frozen_string_literal: true

require_relative 'operator'

module ConceptQL
  module Operators
    # Represents a operator that will grab the Nth occurrence of something
    #
    # Specify occurrences as integers, excluding O
    # 1 => first
    # 2 => second
    # ...
    # -1 => last
    # -2 => second-to-last
    #
    # The operator treats all streams as a single, large stream.  It partitions
    # that larget stream by person_id, then sorts within those groupings
    # by start_date and then select at most one row per person, regardless
    # of how many different types of streams enter the operator
    #
    # If two rows have the same start_date, the order of their ranking
    # is arbitrary
    #
    # If we ask for the second occurrence of something and a person has only one
    # occurrence, this operator returns nothing for that person
    class Occurrence < Operator
      register __FILE__

      preferred_name 'Nth Occurrence'

      desc "Groups all records by person, then orders by start_date and finds the nth occurrence. Can be positive or negative, e.g 2 means 'second' and -3 means 'third from last'."

      argument :occurrence, type: :integer
      category 'Filter Single Stream'
      basic_type :temporal
      allows_one_upstream
      validate_at_least_one_upstream

      option :at_least, type: :string,
                        instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :within, type: :string,
                      instructions: 'Enter a numeric value and specify "d", "m", or "y" for "days", "months", or "years". Negative numbers change dates prior to the existing date. Example: -30d = 30 days before the existing date.'
      option :group_by_date, type: :boolean,
                             instructions: 'Choose whether to group by date when determining the nth occurrence, treating occurrences on the same day as a single occurrence'

      def query_cols
        dynamic_columns + [:rn]
      end

      def occurrence
        @occurrence ||= arguments.first
      end

      def query(db)
        ds = stream.evaluate(db)
        additional_matching_columns = []
        additional_matching_columns << :start_date if grouped?

        ds = ds.select_append(
          Sequel[:ROW_NUMBER].function.over(
            partition: matching_columns_plus(*additional_matching_columns),
            order: ordered_columns(:criterion_id)
          ).as(:rn)
        )
        ds = ds.from_self
        return ds.where(rn: occurrence.abs) unless timed? || grouped?

        additional_order_columns = []

        if grouped?
          one_date_ds = ds.from_self.where(rn: 1).from_self.select_remove(:rn)
          ds = one_date_ds.select_append(
            Sequel[:ROW_NUMBER].function.over(
              partition: matching_columns_plus,
              order: ordered_columns
            ).as(:rn)
          ).from_self
        end
        return ds.where(rn: occurrence.abs) unless timed?

        additional_order_columns << :criterion_id

        input_name = cte_name(:occurrence_input)
        joined_name = cte_name(:occurrence_joined)

        input_ds = ds.select_append(
          Sequel[:ROW_NUMBER].function.over(
            partition: matching_columns_plus,
            order: ordered_columns(*additional_order_columns, allow_reverse: false)
          ).as(:global_rn)
        )

        first_ds = db[input_name].from_self(alias: :first)
        first = Sequel[:first]
        rest = Sequel[:rest]

        joined_ds = first_ds.join(input_name, matching_columns_plus.map { |c| [c, c] }, table_alias: :rest) do
          cond = rest[:global_rn] > first[:global_rn]
          cond &= rest[:start_date] >= adjust_date(at_least_option, first[:end_date]) if at_least_option
          cond &= rest[:start_date] <= adjust_date(within_option, first[:end_date]) if within_option
          cond | { rest[:global_rn] => first[:global_rn] }
        end
          .select_all(:rest)
          .select_append(first[:global_rn].as(:initial_rn))
          .select_append(
            Sequel[:ROW_NUMBER].function.over(
              partition: matching_columns_plus(:global_rn).map { |c| first[c] },
              order: ordered_columns(*additional_order_columns, qualifier: :rest)
            ).as(:timed_rn)
          )

        db[joined_name]
          .with(input_name, input_ds)
          .with(joined_name, joined_ds)
          .where(timed_rn: occurrence.abs)
      end

      def grouped?
        options[:group_by_date]
      end

      def timed?
        options[:at_least] || options[:within]
      end

      def matching_columns_plus(*columns)
        matching_columns + columns
      end

      private

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

      def adjust_date(adjustment, column, reverse = false)
        adjuster = DateAdjuster.new(self, adjustment)
        adjuster.adjust(column, reverse)
      end

      def additional_validation(_db, _opts = {})
        if instance_of?(Occurrence)
          validate_one_argument
        else
          validate_no_arguments
        end
      end

      def asc_or_desc
        occurrence.negative? ? :desc : :asc
      end

      def qualify_with(qualifier, col)
        if qualifier
          Sequel.qualify(qualifier, col)
        else
          col
        end
      end

      def ordered_columns(*columns, qualifier: nil, allow_reverse: true)
        start_date = qualify_with(qualifier, :start_date)
        start_date = Sequel.send(asc_or_desc, start_date) if allow_reverse
        order = [start_date]
        order += columns.map do |c|
          c = qualify_with(qualifier, c)
          c = Sequel.send(asc_or_desc, c) if allow_reverse
          c
        end
        order
      end
    end
  end
end
