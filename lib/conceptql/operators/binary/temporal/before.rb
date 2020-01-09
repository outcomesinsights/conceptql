require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        class Before < Base
          register __FILE__

          desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with an end_date that occurs before the most recent start_date of the RHR is passed through.
All other results are discarded, including all results in the RHR.
          EOF

          allows_at_least_option
          within_skip :before

          def rhs(db, opts = {})
            ds = super
            unless compare_all?
              ds = ds.from_self
                .select_group(*join_columns)
                .select_append(Sequel.function(:max, :start_date).as(:start_date))
                .from_self
            end
            ds
          end

          def where_clause
            before_date = r_start_date

            if at_least_option
              before_date = adjust_date(at_least_option, before_date, true)
            end

            before_clause = Sequel.expr(l_end_date <  before_date)

            if within_option
              before_clause &= l_end_date >= within_start
            end

            before_clause
          end

          def compare_all?
            !(options.keys & [:within]).empty?
          end
        end
      end
    end
  end
end
