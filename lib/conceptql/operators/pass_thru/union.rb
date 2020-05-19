require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Union < Base
        register __FILE__

        desc "Pools sets of incoming results into a single large set of results."
        allows_many_upstreams
        category "Combine Streams"
        validate_at_least_one_upstream
        validate_no_arguments

        def query(db)
          combinables, individuals = upstreams.partition do |upstream|
            upstream.unionable?
          end

          queries = individuals.map do |expression|
            expression.evaluate(db, required_columns: required_columns_for_upstream)
          end

          if (combined = combinables.map(&:dup).inject(&:unionize))
            queries << combined.evaluate(db, required_columns: required_columns_for_upstream)
          end

          queries.inject do |q, query|
            q.union(query, all: true, from_self: false)
          end
        end
      end
    end
  end
end
