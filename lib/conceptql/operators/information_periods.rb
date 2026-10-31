# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class InformationPeriods < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc "Selects all information period records, which have the observation_period domain. " \
           "The operator takes no upstream stream. " \
           "Each argument is an information type concept ID, and with arguments, " \
           "the operator selects only the information periods of those types."
      domains :observation_period
      category "Get Related Data"
      basic_type :selection
      validate_no_upstreams

      def query(db)
        ds = db[source_table]
        ds = ds.where(where_clause) if where_clause
        ds
      end

      def source_table
        dm.table_by_domain(domain)
      end

      def where_clause
        dm.information_period_where_clause(arguments)
      end
    end
  end
end
