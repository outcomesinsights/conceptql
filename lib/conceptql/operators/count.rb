require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Count < PassThru
      register __FILE__

      desc 'Counts the number of results that exactly match across all columns.'
      allows_one_upstream
      validate_one_upstream
      validate_no_arguments

      def query_cols
        SELECTED_COLUMNS - [:value_as_number] + [:value_as_number]
      end

      def query(db)
        db.from(unioned(db))
          .select_group(*(COLUMNS - [:value_as_number]))
          .select_append{count(1).as(:value_as_number)}
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


