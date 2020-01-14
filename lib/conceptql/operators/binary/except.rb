require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Except < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) appears in the right hand results (RHR), it is removed from the output result set.'
        default_query_columns

        def query(db)
          ds = lhs(db)
            .left_join(
              rhs(db),
              join_clause.inject(&:&),
              table_alias: :r
            )
              .where(where_clause)

          prepare_columns(ds)
        end

        def where_clause
          {Sequel[:r][:criterion_id] => nil}
        end

        private

        def join_columns
          %i[criterion_id criterion_table]
        end

        def rhs_columns
          cols = super
          cols |= %i[start_date end_date] unless ignore_dates?
          cols
        end

        def ignore_dates?
          options[:ignore_dates]
        end
      end
    end
  end
end
