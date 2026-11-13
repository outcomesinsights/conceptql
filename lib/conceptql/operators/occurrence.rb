# frozen_string_literal: true

require_relative "operator"
require_relative "../behaviors/single_event"

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
    # The operator takes exactly one upstream. It partitions the records of
    # that upstream by person_id, sorts the records of each person by
    # start_date, and selects at most one row per person, even when the
    # upstream mixes records from several criterion tables. With at_least or
    # within, a person can have more than one row
    #
    # If two rows have the same start_date, criterion_id breaks the tie.
    # criterion_id is unique within one criterion_table, so only rows from
    # two different tables with the same id and start_date still rank in
    # arbitrary order
    #
    # If we ask for the second occurrence of something and a person has only one
    # occurrence, this operator returns nothing for that person
    class Occurrence < Operator
      include ConceptQL::Behaviors::SingleEvent

      register __FILE__

      preferred_name "Nth Occurrence"

      desc "For each person, orders the records by start_date and passes along the record at the given position. " \
           "A positive position counts from the earliest record and a negative one from the most recent record."

      returns "One record per person: the record at the given position. " \
              "A person who has fewer records than the position asks for is not passed along. " \
              "With at_least or within, a person can have more than one record."

      argument :occurrence, type: :integer,
                            meaning: "The position of the record to pass along, as an integer. " \
                                     "A positive number counts from the earliest record, so 1 is the first record and 2 is the second. " \
                                     "A negative number counts from the most recent record, so -1 is the last record and -3 is the third from the last. " \
                                     "0 selects nothing."
      category "Filter Single Stream"
      basic_type :temporal
      validate_one_upstream

      option :at_least, type: :string,
                        instructions: 'Enter a number followed by "d", "w", "m" or "y" for days, weeks, months or years. Example: 30d.',
                        meaning: "A date adjustment, such as 30d. For each record, the operator counts that record and the later records " \
                                 "that start at least this long after it ends, and passes along the record at the given position. " \
                                 "So a person can have more than one record in the result."
      option :within, type: :string,
                      instructions: 'Enter a number followed by "d", "w", "m" or "y" for days, weeks, months or years. Example: 30d.',
                      meaning: "A date adjustment, such as 365d. For each record, the operator counts that record and the later records " \
                               "that start at most this long after it ends, and passes along the record at the given position. " \
                               "So a person can have more than one record in the result."
      option :group_by_date, type: :boolean,
                             instructions: "Choose whether to group by date when determining the nth occurrence, treating occurrences on the same day as a single occurrence",
                             meaning: "Treats the records of a person on one start_date as one occurrence, so the position counts dates. " \
                                      "From the date at that position, the operator passes along the record with the lowest criterion_id, " \
                                      "or the highest criterion_id for a negative position."

      example "For each patient, select the Condition that represents the second occurrence of an MI",
              [ "occurrence", 2, [ "icd9", "412" ] ]
      example "For each patient, the first record on the second day with any of these diagnoses",
              [ "occurrence", 2, [ "icd9", "410.00", "410.01", "250.00", "250.01" ], { "group_by_date" => true } ]

      def query_cols
        dynamic_columns + [ :rn ]
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
          # Name the columns to keep. select_remove(:rn) asked the database
          # for them, and the CTE of a labeled upstream does not exist while
          # the SQL is built (bead conceptql-6k8).
          one_date_ds = ds.from_self.where(rn: 1).from_self.select(*dynamic_columns)
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

        joined_ds = first_ds.join(input_name, matching_columns_plus.map { |c| [ c, c ] }, table_alias: :rest) do
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

        # Each first row nominates its nth rest row. With at_least, several
        # first rows can nominate the same rest row: all rest rows that start
        # after the same gap share one ranking. The join gives one row per
        # nomination, so take the nominated rows from the input instead, and
        # each comes out once (every stream is a set, seed conceptql-0eb).
        nth_ds = db[joined_name].where(timed_rn: occurrence.abs)
        keys = matching_columns_plus(:global_rn).map { |c| Sequel[:l][c] =~ Sequel[:r][c] }

        rdbms.semi_join(db[input_name], nth_ds, *keys)
          .with(input_name, input_ds)
          .with(joined_name, joined_ds)
      end

      # The timed query can pass along several records of one person
      # (bead conceptql-vsqm). First and Last are never timed.
      def events_per_patient
        timed? ? :multiple : super
      end

      def grouped?
        options[:group_by_date]
      end

      # A blank at_least or within counts as not set. An editor can send
      # a blank value for an empty field.
      def timed?
        !(at_least_option || within_option).nil?
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
        order = [ start_date ]
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
