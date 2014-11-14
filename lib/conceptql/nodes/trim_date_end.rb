require_relative 'temporal_node'

module ConceptQL
  module Nodes
    class TrimDateEnd < TemporalNode
      def query(db)
        grouped_right = db.from(right_stream(db)).select_group(:person_id).select_append(Sequel.as(Sequel.function(:min, :start_date), :start_date))
        # If the RHS's min start date is less than the LHS start date,
        # the entire LHS date range is truncated, which implies the row itself
        # is ineligible to pass thru
        db.from(db.from(left_stream(db))
                  .join(Sequel.as(grouped_right, :r), l__person_id: :r__person_id)
                  .where { l__start_date <= r__start_date }
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

