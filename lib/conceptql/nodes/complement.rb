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
            .where(:criterion_type => type.to_s)
          query = db.from(make_table_name(type))
            .exclude(make_type_id(type) => positive_query)
          db.from(select_it(query, type))
        end.inject do |union_query, q|
          union_query.union(q, all: true)
        end
      end

=begin
This is an alternate, but equally accurate way to do complement.
We'll need to benchmark which is faster.
      def query2(db)
        child = children.first
        froms = child.types.map do |type|
          select_it(db.from(make_table_name(type)), type)
        end
        big_from = froms.inject { |union_query, q| union_query.union(q, all:true) }
        db.from(big_from).except(child.evaluate(db))
      end
=end
    end
  end
end
