# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    class Dedup < PassThru
      register __FILE__
      effects :keep
      hidden
      category "Filter Single Stream"

      desc "Passes along each distinct result once. Results that have the same value in every column become one result."
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
