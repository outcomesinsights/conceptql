require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Dedup < PassThru
      register __FILE__

      desc 'Counts the number of results that exactly match across all columns.'
      allows_one_upstream
      validate_one_upstream

      def query(db)
        db.from(unioned(db))
          .select_group(*desired_columns)
          .from_self
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
          uni.union(q)
        end
      end

      def desired_columns
        return options[:query_columns] if options[:query_columns]
        columns = query_cols

        columns &= options[:only_columns] if options[:only_columns]
        columns -= options[:except_columns] if options[:except_columns]
        columns
      end
    end
  end
end


