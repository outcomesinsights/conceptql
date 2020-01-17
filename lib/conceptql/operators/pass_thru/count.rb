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
        output_column :lab_value_as_number

        def query(db)
          unioned(db)
            .select_group(*(required_columns - [:lab_value_as_number]))
            .select_append{count(1).as(:lab_value_as_number)}
            .from_self
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
