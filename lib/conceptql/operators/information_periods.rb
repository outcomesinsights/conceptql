# frozen_string_literal: true

require_relative 'operator'

module ConceptQL
  module Operators
    class InformationPeriods < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming record set.'
      domains :observation_period
      category 'Get Related Data'
      basic_type :selection
      validate_no_upstreams

      def query(db)
        ds = db[source_table]
        ds = ds.where(where_clause) if where_clause
        ds
      end

      def source_table
        tab = dm.table_by_domain(domain)
        tab = :payer_plan_period if tab == :observation_period && ConceptQL::Utils.present?(arguments)
        tab
      end

      def where_clause
        dm.information_period_where_clause(arguments)
      end
    end
  end
end
