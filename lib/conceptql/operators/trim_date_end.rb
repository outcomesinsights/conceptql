require_relative 'temporal_operator'

module ConceptQL
  module Operators
    # Trims the end_date of the LHS set of results by the RHS's earliest
    # start_date (per person)
    # If a the RHS contains a start_date that comes before the LHS's start_date
    # that LHS result is completely discarded.
    #
    # If there is no RHS result for an LHS result, the LHS result is passed
    # thru unaffected.
    #
    # If the RHS result's start_date is later than the LHS end_date, the LHS
    # result is passed thru unaffected.
    class TrimDateEnd < TemporalOperator
      register __FILE__

      desc <<-EOF
Trims the end_date of the left hand results (LHR) by the earliest
start_date (per person) in the right hand results (RHR)
If the RHR contains a start_date that comes before the start_date in the LHR
that result in the LHR is completely discarded.

If there is no result in the RHR for a result in the LHR, the result in the LHR is passed
through unaffected.

If the start_date of the result in the RHR is later than the end_date of the result in the LHR, the result in the LHR
is passed through unaffected.
      EOF

      allows_one_upstream

      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:min, :start_date), :start_date))

        where_criteria = (l_start_date <= within_start) | { r_start_date => nil }

        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        ds = db.from(left_stream(db))
                  .left_join(Sequel.as(grouped_right, :r), person_id: :person_id)
                  .where(where_criteria)

        ds = dm.selectify(ds, qualifier: :l, replace: { end_date: Sequel.function(:least, l_end_date, within_start) })
        ds = add_occurrences_condition(ds, occurrences_option)

        ds.from_self
      end

      def within_column
        Sequel[:l][:end_date]
      end

      private
      def new_columns
        (dynamic_columns - [:end_date]).map { |col| Sequel[:l][col] }
      end
    end
  end
end

