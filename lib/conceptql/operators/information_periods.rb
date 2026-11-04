# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class InformationPeriods < Operator
      register __FILE__

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::Timeless

      desc "Selects information periods: the spans of time in which the data has information about a patient, " \
           "such as periods of insurance enrollment."
      argument :information_types, label: "Information Type Concept IDs", type: :codelist,
                                   meaning: "Zero or more information type concept IDs, as integers. " \
                                            "With no IDs, the operator selects every information period. " \
                                            "With IDs, it selects only the information periods whose type is one of them."
      returns "One record for each selected information period, from the information_periods table. " \
              "The type of the records is observation_period."
      example "All information periods", [ "information_periods" ]
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
