module ConceptQL
  module Vocabularies
    module Behaviors
      module Gdmish
        def exclusion_clause(db)
          return {} unless select_all?
          { clinical_code_concept_id: 0 }
        end

        def additional_columns(db)
          [ Sequel.cast_string(domain.to_s).as(:criterion_domain) ]
        end
      end
    end
  end
end

