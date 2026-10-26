# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Dedup < PassThru
      register __FILE__

      desc "Counts the number of records that exactly match across all columns."
      allows_one_upstream
      validate_one_upstream

      def query(db)
        db.from(unioned(db))
          .select_group(*query_cols)
          .from_self
      end

      def query_cols
        dynamic_columns
      end

      def unioned(db)
        upstreams.map { |c| c.evaluate(db) }.inject do |uni, q|
          uni.union(q)
        end
      end
    end
  end
end
