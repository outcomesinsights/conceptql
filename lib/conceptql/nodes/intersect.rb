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
          expression.types.each do |type|
            (exprs[type] ||= []) << expression.evaluate(db)
          end
        end
        typed_queries = exprs.map do |type, queries|
          queries.inject do |q, query|
            q.intersect(query, all: true)
          end
        end

        typed_queries.inject do |q, query|
          q.union(query, all: true)
        end
      end
    end
  end
end
