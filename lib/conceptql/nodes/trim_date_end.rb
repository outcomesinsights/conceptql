require_relative 'temporal_node'

module ConceptQL
  module Nodes
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
    class TrimDateEnd < TemporalNode
      desc <<-EOF
Trims the end_date of the LHS set of results by the RHS's earliest
start_date (per person)
If a the RHS contains a start_date that comes before the LHS's start_date
that LHS result is completely discarded.

If there is no RHS result for an LHS result, the LHS result is passed
thru unaffected.

If the RHS result's start_date is later than the LHS end_date, the LHS
result is passed thru unaffected.
      EOF
      allows_one_child

      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:min, :start_date), :start_date))

        where_criteria = Sequel.expr { l__start_date <= r__start_date }
        where_criteria = where_criteria.|(r__start_date: nil)

        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        db.from(db.from(left_stream(db))
                  .left_join(Sequel.as(grouped_right, :r), l__person_id: :r__person_id)
                  .where(where_criteria)
                  .select(*new_columns)
                  .select_append(Sequel.as(Sequel.function(:least, :l__end_date, :r__start_date), :end_date))
               )
      end

      private
      def new_columns
        (COLUMNS - [:end_date]).map { |col| "l__#{col}".to_sym }
      end
    end
  end
end

