require_relative 'operator'

module ConceptQL
  module Operators
    class DrugTypeConcept < Operator
      register __FILE__, :omopv4

      desc 'Given a set of concept IDs in RxNorm, returns that set of drug exposures'
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


