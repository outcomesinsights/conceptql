module ConceptQL
  module Provenanceable

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    def prov_of(ancestors)
      with_lexicon(db) do |lexicon|
        lexicon.descendants_of(lexicon.concept_ids([lexicon.file_provenance_types_vocab, lexicon.code_provenance_types_vocab], ancestors))
      end
    end

    def build_where_from_codes(codes)
      Sequel.|(
        {file_provenance_type: prov_of(codes)}, {code_provenance_type: prov_of(codes)}
      )
    end

    def find_bad_keywords(codes) 
      with_lexicon(db) do |lexicon|
        codes - lexicon.concepts([lexicon.file_provenance_types_vocab, lexicon.code_provenance_types_vocab]).select_map(:concept_code)
      end
    end
  end
end
