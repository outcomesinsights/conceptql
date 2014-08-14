require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Complement < PassThru
      def query(db)
        child = children.first
        child.types.map do |type|
          positive_query = db.from(child.evaluate(db))
            .select(:criterion_id)
            .exclude(:criterion_id => nil)
          query = db.from(make_table_name(type))
            .exclude(type_id(type) => positive_query)
          db.from(select_it(query, type))
        end.inject do |union_query, q|
          union_query.union(q, all: true)
        end
      end
    end
  end
end
