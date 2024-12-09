# frozen_string_literal: true

module ConceptQL
  module Provenanceable
    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    def prov_of(db, ancestors)
      dm.descendants_of(db,
                        dm.concept_ids(db, [dm.file_provenance_types_vocab, dm.code_provenance_types_vocab].flatten,
                                       ancestors))
    end

    def build_where_from_codes(db, codes)
      Sequel.|(
        { file_provenance_type: prov_of(db, codes) }, { code_provenance_type: prov_of(db, codes) }
      )
    end

    def find_bad_keywords(db, codes)
      codes - dm.concepts(db,
                          [dm.file_provenance_types_vocab,
                           dm.code_provenance_types_vocab].flatten).select_map(:concept_code)
    end
  end
end
