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
      composite_codes, regular_codes = codes.partition { |code| code.include?(':') }

      conditions = []

      # Handle regular codes
      conditions << build_provenance_condition(db, regular_codes) if regular_codes.any?

      # Handle composite codes (with ':')
      composite_codes.each do |code|
        split_conditions = code.split(':').map { |split_code| build_provenance_condition(db, [split_code]) }
        conditions << Sequel.&(*split_conditions)
      end

      conditions.size == 1 ? conditions.first : Sequel.|(*conditions)
    end

    def find_bad_keywords(db, codes)
      valid_codes = dm.concepts(db, provenance_vocabs).select_map(:concept_code)

      codes.reject do |code|
        split_codes = code.include?(':') ? code.split(':') : [code]
        split_codes.all? { |split_code| valid_codes.include?(split_code) }
      end
    end

    private

    def build_provenance_condition(db, codes)
      prov_codes = prov_of(db, codes)
      Sequel.|(
        { file_provenance_type: prov_codes },
        { code_provenance_type: prov_codes }
      )
    end

    def provenance_vocabs
      [dm.file_provenance_types_vocab, dm.code_provenance_types_vocab].flatten
    end
  end
end
