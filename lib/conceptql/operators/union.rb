require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Union < PassThru
      register __FILE__, :omopv4

      desc 'Pools sets of incoming results into a single large set of results.'
      allows_many_upstreams
      category 'Set Logic'
      default_query_columns
      validate_at_least_one_upstream
      validate_no_arguments

      def query(db)
        upstreams.map do |expression|
          expression.evaluate(db).from_self
        end.inject do |q, query|
          q.union(query, all: true)
        end
      end

      def flattened
        exprs = []
        upstreams.each do |x|
          if x.is_a?(Union)
            exprs.concat x.flattened.upstreams
          else
            exprs << x
          end
        end
        dup_values(exprs)
      end

      def optimized
        first, *rest = flattened.upstreams
        exprs = [first]

        rest.each do |expression|
          add = true
          exprs.length.times do |i|
            exp = exprs[i]
            if exprs[i].unionable?(expression)
              exprs[i] = exp.union(expression)
              add = false
              break
            end
          end
          exprs << expression if add
        end

        dup_values(exprs.map{|x| x.is_a?(Operator) ? x.optimized : x})
      end
    end
  end
end
