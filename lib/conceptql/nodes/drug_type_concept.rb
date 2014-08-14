require_relative 'node'

module ConceptQL
  module Nodes
    class DrugTypeConcept < Node
      def type
        :drug_exposure
      end

      def query(db)
        db.from(:drug_exposure)
          .where(drug_type_concept_id: arguments)
      end
    end
  end
end


