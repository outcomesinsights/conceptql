require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Union < PassThru
      register __FILE__

      desc 'Pools sets of incoming results into a single large set of results.'
      allows_many_upstreams
      category 'Set Logic'

      def query(db)
        first, *rest = values
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

        exprs.map do |expression|
          expression.evaluate(db).from_self
        end.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
