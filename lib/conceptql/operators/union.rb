require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Union < PassThru
      register __FILE__

      desc 'Pools sets of incoming results into a single large set of results.'
      allows_many_upstreams
      category 'Set Logic'

      def query(db)
        values.map do |expression|
          expression.evaluate(db).from_self
        end.inject do |q, query|
          q.union(query, all: true)
        end
      end

      def flattened
        exprs = []
        values.each do |x|
          if x.is_a?(Union)
            exprs.concat x.flattened.values
          else
            exprs << x
          end
        end
        dup_values(exprs)
      end

      def optimized
        first, *rest = flattened.values
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
