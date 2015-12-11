require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Complement < PassThru
      desc 'Splits up the incoming result set by type and passes through all results for each type that are NOT in the current set.'
      allows_one_upstream
      category 'Set Logic'

      def query(db)
        upstream = upstreams.first
        upstream.types.map do |type|
          positive_query = db.from(upstream.evaluate(db))
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


      # This is an alternate, but equally accurate way to do complement.
      # We'll need to benchmark which is faster.
      def query2(db)
        upstream = upstreams.first
        froms = upstream.types.map do |type|
          select_it(db.from(make_table_name(type)), type)
        end
        big_from = froms.inject { |union_query, q| union_query.union(q, all:true) }
        db.from(big_from).except(upstream.evaluate(db))
      end
    end
  end
end
