require_relative "base"

module ConceptQL
  module Operators
    module Selection
      class InformationPeriods < Base
        register __FILE__

        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Timeless

        desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming result set.'
        domains :observation_period
        category "Get Related Data"
        basic_type :selection
        validate_no_upstreams

        def table
          dm.nschema.information_periods.view
        end

        def where_clause(db)
          dm.information_period_where_clause(arguments)
        end
      end
    end
  end
end
