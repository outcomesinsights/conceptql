module ConceptQL
  module Vocabularies
    module Behaviors
      module Gdmish
        def additional_columns(db)
          [ Sequel.cast_string(domain.to_s).as(:criterion_domain) ]
        end
      end
    end
  end
end

