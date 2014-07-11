require_relative 'pass_thru'

module ConceptQL
  module Nodes
    class Complement < PassThru
      def query(db)
        child = children.first
        child.types.map do |type|
          select_it(db.from(make_table_name(type)).exclude(type_id(type) => child.evaluate(db).select(type_id(type)).from_self.exclude(type_id(type) => nil)), [type])
        end.inject do |union_query, q|
          union_query.union(q, all: true)
        end
      end
    end
  end
end
