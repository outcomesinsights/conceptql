require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Intersect < PassThru
      def types
        values.map(&:types).flatten.uniq
      end

      def query(db)
        exprs = {}
        values.each do |expression|
          evaled = expression.evaluate(db)
          expression.types.each do |type|
            (exprs[type] ||= []) << evaled
          end
        end
        typed_queries = exprs.map do |type, queries|
          queries.inject do |q, query|
            q.intersect(query)
          end
        end

        typed_queries.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
