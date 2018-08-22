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
          .where(where_clause)
      end

      def source_table
        tab = dm.table_by_domain(domain)
        if tab == :observation_period && ConceptQL::Utils.present?(arguments)
          tab = :payer_plan_period
        end
        tab
      end

      def where_clause
        dm.information_period_where_clause(arguments)
      end
    end
  end
end

