# frozen_string_literal: true

require_relative "temporal_operator"

module ConceptQL
  module Operators
    # Trims the end_date of the LHS set of records by the RHS's earliest
    # start_date (per person)
    # If a the RHS contains a start_date that comes before the LHS's start_date
    # that LHS record is completely discarded.
    #
    # If there is no RHS record for an LHS record, the LHS record is passed
    # thru unaffected.
    #
    # If the RHS record's start_date is later than the LHS end_date, the LHS
    # record is passed thru unaffected.
    #
    # With join_columns (only t_shank gives it), "per person" means per
    # person and join_columns values, with or without compare_all.
    #
    # With compare_all (only t_shank gives it), each LHS record is compared
    # with every RHS record of the person and of the join_columns, not only
    # with the person's first (trim_date_end) or last (trim_date_start) RHS
    # record. Each LHS record comes out once, trimmed by the nearest RHS
    # record that passes: the earliest start_date on or after its start_date
    # (trim_date_end), or the latest end_date on or before its end_date
    # (trim_date_start). An LHS record is discarded only when it has RHS
    # records and none of them passes.
    class TrimDate < TemporalOperator
      desc <<~EOF
        Trims the end_date of the left hand records (LHR) by the earliest
        start_date (per person) in the right hand records (RHR)
        If the RHR contains a start_date that comes before the start_date in the LHR
        that record in the LHR is completely discarded.

        If there is no record in the RHR for a record in the LHR, the record in the LHR is passed
        through unaffected.

        If the start_date of the record in the RHR is later than the end_date of the record in the LHR, the record in the LHR
        is passed through unaffected.
      EOF

      def query(db)
        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        ds = db.from(left_stream(db)).from_self(alias: :l)
               .left_join(Sequel.as(right_stream_query(db), :r), join_columns.inject(&:&))
               .where(where_criteria)

        ds = nearest_trim_date(ds) if compare_all?

        ds = dm.selectify(ds, qualifier: :l, replace: replacement_columns)

        ds = apply_selectors(ds)

        ds.from_self
      end

      private

      def compare_all?
        options[:compare_all]
      end

      # With compare_all, each left row joins every right row of the person
      # (and of the join columns), and the where clause keeps the right rows
      # that pass. Group those back to one row for each left row, and keep
      # the nearest passing trim date (trim_function). A left row without a
      # right row has a NULL trim date, so it passes through unchanged (bead
      # conceptql-x6m, seed conceptql-ysx). Every stream is a set, so left
      # rows that are equal in every column come out once (seed conceptql-0eb).
      def nearest_trim_date(ds)
        ds.select_group(*dynamic_columns.map { |column| Sequel[:l][column] })
          .select_append(Sequel.function(trim_function, trim_bound).as(:trim_bound))
          .from_self(alias: :l)
      end

      # The trim date of the joined right row, or the nearest one of the left
      # row when compare_all grouped the right rows.
      def trim_date_column
        compare_all? ? Sequel[:l][:trim_bound] : trim_bound
      end

      def right_stream_query(db)
        rh = compare_all? ? super : nearest_right_row(db)
        columnizer.apply(rh)
      end

      # Without compare_all, the first (trim_date_end) or last
      # (trim_date_start) right row of each person and join_columns values,
      # the grouping compare_all uses. The rows are ordered as the occurrence
      # operator orders them: by start_date, then criterion_id. The occurrence
      # operator groups by person only, so a left row whose join values
      # differed from those of the person's first right row passed through
      # untrimmed (bead conceptql-18n).
      def nearest_right_row(db)
        direction = occurrence_number.negative? ? :desc : :asc
        right.evaluate(db)
             .select_append(Sequel[:ROW_NUMBER].function.over(
               partition: join_columns_option.uniq,
               order: %i[start_date criterion_id].map { |column| Sequel.send(direction, column) }
             ).as(:rn))
             .from_self
             .where(rn: occurrence_number.abs)
      end

      def columnizer
        columnizer = Columnizer.new
        columnizer.add_columns(:person_id, trim_date, *join_columns_option)
        columnizer
      end
    end
  end
end
