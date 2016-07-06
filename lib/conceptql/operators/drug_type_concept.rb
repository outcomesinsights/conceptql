require_relative 'operator'

module ConceptQL
  module Operators
    class DrugTypeConcept < Operator
      register __FILE__

      desc 'Returns all drug_exposures that match the given set of Drug Type concept IDs.'
      argument :concept_ids, type: :codelist, vocab: 'RxNorm'
      query_columns :drug_exposure
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def domain
        :drug_exposure
      end

      def query(db)
        db.from(:drug_exposure)
          .where(drug_type_concept_id: arguments)
      end
    end
  end
end


