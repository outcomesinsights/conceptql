require_relative 'temporal_node'

module ConceptQL
  module Nodes
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
    class TrimDateStart < TemporalNode
      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:max, :end_date), :end_date))

        where_criteria = Sequel.expr { l__end_date >= r__end_date }
        where_criteria = where_criteria.|(r__end_date: nil)

        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        db.from(db.from(left_stream(db))
                  .join(Sequel.as(grouped_right, :r), l__person_id: :r__person_id)
                  .where(where_criteria)
                  .select(*new_columns)
                  .select_append(Sequel.as(Sequel.function(:greatest, :l__start_date, :r__end_date), :start_date))
               )
      end

      private
      def new_columns
        (COLUMNS - [:start_date]).map { |col| "l__#{col}".to_sym }
      end
    end
  end
end


