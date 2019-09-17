require_relative "../../operators/vocabulary"

module ConceptQL
  module Vocabularies
    module Behaviors
      module Costish
        def query(db)
          costs = db[:procedure_cost].where(column_to_search => values).select(:procedure_occurrence_id)
          db[:procedure_occurrence].where(procedure_occurrence_id: costs)
        end

        def table
          :procedure_occurrence
        end

        def column_to_search
          vocab_entry.id == "revenue_code" ? :revenue_code_source_value : :disease_class_source_value
        end
      end
    end
  end
end

