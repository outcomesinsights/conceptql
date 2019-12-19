require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Union < Base
        register __FILE__

        desc "Pools sets of incoming results into a single large set of results."
        allows_many_upstreams
        category "Combine Streams"
        default_query_columns
        validate_at_least_one_upstream
        validate_no_arguments

        def query(db)
          combinables, individuals = upstreams.partition do |upstream|
            upstream.unionable?
          end

          queries = individuals.map do |expression|
            expression.evaluate(db)
          end

          queries << combinables.inject(&:unionize).evaluate(db).from_self
          queries.inject do |q, query|
            q.union(query, all: true)
          end
        end

        def timeless?
          !(defined?(@running_combos) && @running_combos)
        end

        def process_combos
          @running_combos = true
          ds = yield
          @running_combos = false
          ds
        end
      end
    end
  end
end
