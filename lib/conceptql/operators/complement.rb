require_relative 'pass_thru'

module ConceptQL
  module Operators
    class Complement < PassThru
      register __FILE__

      desc 'Splits up the incoming result set by domain and passes through all results for each domain that are NOT in the current set.'
      allows_one_upstream
      category "Filter Single Stream"
      basic_type :temporal
      default_query_columns
      validate_one_upstream
      validate_no_arguments

      # TODO: This is going to fail under GDM
      # The problem is that most domains live in clinical_codes, so we'll end up
      def query(db)
        upstream = upstreams.first
        upstream.domains(db).map do |domain|
          positive_query = db.from(upstream.evaluate(db))
            .select(:criterion_id)
            .exclude(:criterion_id => nil)
            .where(:criterion_domain => domain.to_s)
          query = db.from(dm.table_by_domain(domain))
            .exclude(dm.pk_by_domain(domain) => positive_query)
          db.from(dm.selectify(query, domain: domain))
        end.inject do |union_query, q|
          union_query.union(q, all: true)
        end
      end

      # This is an alternate, but equally accurate way to do complement.
      # We'll need to benchmark which is faster.
      #def query2(db)
      #  upstream = upstreams.first
      #  froms = upstream.domains.map do |domain|
      #    select_it(db.from(make_table_name(domain)), domain)
      #  end
      #  big_from = froms.inject { |union_query, q| union_query.union(q, all:true) }
      #  db.from(big_from).except(upstream.evaluate(db))
      #end
    end
  end
end
