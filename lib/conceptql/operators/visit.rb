require_relative 'operator'

module ConceptQL
  module Operators
    class Visit < Operator
      register __FILE__, :omopv4

      desc 'Generates all visit_occurrence records, or, if fed a stream, fetches all visit_occurrence records for the people represented in the incoming result set.'
      types :visit_occurrence
      allows_one_upstream

      def query(db)
        ds = db.from(:visit_occurrence)
        if upstream = upstreams.first
          ds = ds.where(:person_id=>upstream.query(db).select(:person_id))
        end
        ds
      end

      def types
        [:visit_occurrence]
      end
    end
  end
end
