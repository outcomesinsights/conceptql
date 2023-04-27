require_relative 'operator'
require_relative '../behaviors/drugish'

module ConceptQL
  module Operators
    class DrugTypeConcept < Operator
      register __FILE__

      desc 'Selects all drug_exposures that match the given set of Drug Type concept IDs.'
      argument :concept_ids, type: :codelist, vocab: 'Drug Type'
      domains :drug_exposure
      query_columns :drug_exposure
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument
      deprecated replaced_by: "provenance"
      include ConceptQL::Behaviors::Drugish

      def domain
        :drug_exposure
      end

      def query(db)
        db.from(dm.table_by_domain(domain))
          .where(dm.type_concept_id_column(dm.table_by_domain(domain)) => arguments)
      end
    end
  end
end


