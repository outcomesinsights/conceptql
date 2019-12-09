require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Count < Base
        register __FILE__

        desc 'Counts the number of results that exactly match across all columns.'
        allows_one_upstream
        validate_one_upstream
        validate_no_arguments
        require_column :value_as_number

        def query_cols
          dynamic_columns - [:value_as_number] + [:value_as_number]
        end

        def query(db)
          db.from(unioned(db))
            .select_group(*(query_cols - [:value_as_number]))
            .select_append{count(1).as(:value_as_number)}
            .from_self
        end

        def unioned(db)
          upstreams.map { |c| c.evaluate(db).select(*query_cols) }.inject do |uni, q|
            uni.union(q)
          end
        end
      end
    end
  end
end
