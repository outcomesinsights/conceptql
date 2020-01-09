require_relative "base"

module ConceptQL
  module Operators
    module Binary
      module Temporal
        class After < Base
          register __FILE__

          desc <<-EOF
Compares all results on a person-by-person basis between the left hand results (LHR) and the right hand results (RHR).
Any result in the LHR with a start_date that occurs after the earliest end_date in the RHR is passed through.
All other results are discarded, including all results in the RHR.
L-------N-------L
R-----R
   R-----R
        L-----Y----L
          EOF

          allows_at_least_option
          within_skip :after

          def rhs(db, opts = {})
            ds = super
            if compare_all?
              ds = ds.from_self
                .select_group(*join_columns)
                .select_append(Sequel.function(:min, :end_date).as(:end_date))
            end
            ds.from_self(alias: :r)
          end

          def where_clause
            after_date = r_end_date

            if at_least_option
              after_date = adjust_date(at_least_option, after_date)
            end

            clause = Sequel.expr(l_start_date > after_date)

            if within_option
              clause = clause.&(l_start_date <= within_end)
            end

            clause
          end

          def compare_all?
            !options.has_key?(:within)
          end
        end
      end
    end
  end
end

