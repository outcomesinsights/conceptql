module ConceptQL
  module Vocabularies
    module Behaviors
      module Gdmish
        def apply_exclusion(ds)
          return ds unless select_all?
          ds.exclude(clinical_code_concept_id: 0)
        end

        def apply_additional_columns(ds)
          ds.select_append(Sequel.cast_string(domain.to_s).as(:criterion_domain))
        end
      end
    end
  end
end

