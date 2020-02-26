require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Sum < Base
        register __FILE__

        desc <<-EOF
Sums lab_value_as_number across all results that match on all but start_date, end_date.
For start_date and end_date the min and max of each respectively is returned.'
        EOF
        validate_at_least_one_upstream
        validate_no_arguments
        output_column :lab_value_as_number

        def query(db)
          cols = required_columns
          cols -= %i[start_date end_date criterion_id lab_value_as_number]

          unioned(db)
            .select_group(*cols)
            .select_append(Sequel.cast_numeric(0).as(:criterion_id))
            .select_append{ min(start_date).as(:start_date) }
            .select_append{ max(end_date).as(:end_date) }
            .select_append{sum(lab_value_as_number).as(:lab_value_as_number)}
            .from_self
        end

        def required_columns
          super | %i[lab_value_as_number]
        end

        def unioned(db)
          upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
            uni.union(q)
          end
        end
      end
    end
  end
end
