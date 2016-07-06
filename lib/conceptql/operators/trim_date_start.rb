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

      desc <<-EOF
Trims the start_date of the left hand results (LHR) by the final
end_date (per person) in the right hand results (RHR)
If the RHR contain an end_date that comes after the end_date in the LHR
that result in the LHR is completely discarded.

If there is no result in the RHR for a result in the LHR, the result in the LHR is passed
through unaffected.

If the end_date of the result in the RHR is earlier than the start_date of the result in the LHR, the result in the LHR
is passed through unaffected.
      EOF

      allows_one_upstream
      within_skip :after

      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:max, :end_date), :end_date))

        where_criteria = Sequel.expr { l__end_date >= r__end_date }
        where_criteria = where_criteria.|(r__end_date: nil)

        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        ds = db.from(left_stream(db))
                  .join(Sequel.as(grouped_right, :r), l__person_id: :r__person_id)
                  .where(where_criteria)
                  .select(*new_columns)
                  .select_append(Sequel.as(Sequel.function(:greatest, :l__start_date, :r__end_date), :start_date))

        ds = add_option_conditions(ds)
        ds.from_self
      end

      private

      def occurrences_column
        :end_date
      end

      def new_columns
        (COLUMNS - [:start_date]).map { |col| "l__#{col}".to_sym }
      end
    end
  end
end


