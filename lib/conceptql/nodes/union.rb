require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Union < PassThru
      desc 'Pools sets of incoming results into a single large set of results.'
      allows_many_children
      category 'Set Logic'

      def query(db)
        values.map do |expression|
          expression.evaluate(db).from_self
        end.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
