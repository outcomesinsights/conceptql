require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
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
        class TrimDate < Base
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
            # If the RHS's min start date is less than the LHS start date,
            # the entire LHS date range is truncated, which implies the row itself
            # is ineligible to pass thru
            ds = lhs(db)
              .left_join(rhs(db), join_clause.inject(&:&), table_alias: :r)
              .where(where_criteria)
            prepare_columns(ds)
          end

          def within_column
            Sequel[:l][:end_date]
          end

          private

          def compare_all?
            options[:compare_all]
          end

          def rhs(db)
            return super if compare_all?
            occ = to_op([:occurrence, occurrence_number, right])
            occ.evaluate(db).from_self(alias: :r)
          end
        end
      end
    end
  end
end
