require_relative 'temporal_operator'

module ConceptQL
  module Operators
    # Trims the start_date of the LHS set of results by the RHS's latest
    # end_date (per person)
    # If a the RHS contains an end_date that comes after the LHS's end_date
    # that LHS result is completely discarded.
    #
    # If there is no RHS result for an LHS result, the LHS result is passed
    # thru unaffected.
    #
    # If the RHS result's end_date is earlier than the LHS start_date, the LHS
    # result is passed thru unaffected.
    class TrimDateStart < TemporalOperator
      register __FILE__
      category "Filter by Comparing"

      desc <<-EOF
Trims the start_date of the left hand results (LHR) by the final
end_date (per person) in the right hand results (RHR)
If the RHR contains an end_date that comes after the end_date in the LHR
that result in the LHR is completely discarded.

If there is no result in the RHR for a result in the LHR, the result in the LHR is passed
through unaffected.

If the end_date of the result in the RHR is earlier than the start_date of the result in the LHR, the result in the LHR
is passed through unaffected.
      EOF

      allows_one_upstream

      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:max, :end_date), :end_date))

        where_criteria = (l_end_date >= within_end) | { within_end => nil }

        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        ds = db.from(left_stream(db))
                  .left_join(Sequel.as(grouped_right, :r), person_id: :person_id)
                  .where(where_criteria)
                  .select(*new_columns)
                  .select_append(Sequel.as(Sequel.function(:greatest, Sequel[:l][:start_date], within_end), :start_date))

        ds.from_self
      end

      private

      def new_columns
        (dynamic_columns - [:start_date]).map { |col| Sequel[:l][col] }
      end
    end
  end
end


