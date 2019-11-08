require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class Except < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) appears in the right hand results (RHR), it is removed from the output result set.'
        default_query_columns

        def query(db)
          if ignore_dates?
            query = db.from(Sequel.as(left.evaluate(db), :l))
              .left_join(Sequel.as(right.evaluate(db), :r), criterion_id: :criterion_id, criterion_domain: :criterion_domain)
              .where(Sequel[:r][:criterion_id] => nil)
              .select_all(:l)
            db.from(query)
          else
            lquery = left.evaluate(db)
            rquery = right.evaluate(db)

            # Set columns so that impala's EXCEPT emulation doesn't use a query to determine them
            lquery.send("columns=", query_cols)
            rquery.send("columns=", query_cols)

            if impala?
              lquery = lquery.except_strategy(:not_exists, *(matching_columns + [:criterion_id, :criterion_domain]))
            end
            lquery.select(*query_cols).except(rquery.select(*query_cols))
          end
        end

        private

        def ignore_dates?
          options[:ignore_dates]
        end
      end
    end
  end
end
