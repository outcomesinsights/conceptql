require_relative "operator"

module ConceptQL
  module Operators
    class InformationPeriods < Operator
      register __FILE__

      desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming result set.'
      domains :observation_period
      category "Get Related Data"
      basic_type :selection
      validate_no_upstreams

      def query(db)
        db[source_table]
      end

      def source_table
        dm.table_by_domain(domain)
      end
    end
  end
end

