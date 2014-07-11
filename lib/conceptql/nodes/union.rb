require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Union < PassThru
      def query(db)
        values.map do |expression|
          expression.evaluate(db)
        end.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
