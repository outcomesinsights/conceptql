require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Intersect < PassThru
      register __FILE__

      desc 'Passes through any result that appears in all incoming result sets.'
      allows_many_upstreams
      category "Combine Streams"
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments

      def query(db)
        exprs = {}
        upstreams.each do |expression|
          evaled = expression.evaluate(db)
          expression.domains.each do |domain|
            (exprs[domain] ||= []) << evaled
          end
        end
        domained_queries = exprs.map do |domain, queries|
          queries.inject do |q, query|
            # Set columns so that impala's INTERSECT emulation doesn't use a query to determine them
            q.instance_variable_set(:@columns, query_cols)
            query.instance_variable_set(:@columns, query_cols)

            q.intersect(query)
          end
        end

        domained_queries.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
