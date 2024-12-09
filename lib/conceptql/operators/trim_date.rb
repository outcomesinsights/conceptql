# frozen_string_literal: true

require_relative 'temporal_operator'

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

      allows_one_upstream

      def query(db)
        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        ds = db.from(left_stream(db)).from_self(alias: :l)
               .left_join(Sequel.as(right_stream_query(db), :r), join_columns.inject(&:&))
               .where(where_criteria)

        ds = dm.selectify(ds, qualifier: :l, replace: replacement_columns)

        ds = apply_selectors(ds)

        ds.from_self
      end

      def within_column
        Sequel[:l][:end_date]
      end

      private

      def compare_all?
        options[:compare_all]
      end

      def right_stream_query(db)
        rh = if compare_all?
               super
             else
               occ = to_op([:occurrence, occurrence_number, right])
               occ.evaluate(db)
             end
        columnizer.apply(rh)
      end

      def columnizer
        columnizer = Columnizer.new
        columnizer.add_columns(:person_id, trim_date, *join_columns_option)
        columnizer
      end
    end
  end
end
