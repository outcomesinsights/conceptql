# frozen_string_literal: true

module ConceptQL
  # Provenance keywords select records by their file provenance
  # (file_provenance_type) and their code provenance (code_provenance_type).
  #
  # A plain keyword, such as "inpatient" or "primary", names a concept in the
  # file or the code provenance vocabulary. It keeps a record when either
  # column is in the descendants of that concept.
  #
  # A keyword "<file keyword>:<code keyword>", such as
  # "inpatient:primary_or_first", keeps a record when its file provenance is
  # in the descendants of the file keyword AND its code provenance is in the
  # descendants of the code keyword.
  #
  # Several keywords are ORed: a record is kept when any keyword keeps it.
  module Provenanceable
    PAIR_SEPARATOR = ":"

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    def build_where_from_codes(db, codes)
      pairs, plain = codes.partition { |code| pair_keyword?(code) }
      conditions = pairs.map { |pair| pair_condition(db, pair) }
      # With no keywords at all, the plain condition is built as before.
      conditions.unshift(plain_condition(db, plain)) if plain.any? || pairs.empty?
      return conditions.first if conditions.one?

      Sequel.|(*conditions)
    end

    # The keywords as written that name no provenance concept. A pair is
    # recognized only when it has one separator, a file keyword on the left
    # and a code keyword on the right. Case is ignored, as the lookup ignores
    # it (LexiconStrategy#concepts compares lower(concept_code) with the
    # keyword in lower case), so "Inpatient" names the concept "inpatient".
    def find_bad_keywords(db, codes)
      pairs, plain = codes.partition { |code| pair_keyword?(code) }
      known = known_keywords(db, all_provenance_types_vocab)
      bad = plain.reject { |code| known.include?(code.to_s.downcase) }
      bad += pairs.reject { |pair| known_pair?(db, pair) }
      codes & bad
    end

    private

    def pair_keyword?(code)
      code.to_s.include?(PAIR_SEPARATOR)
    end

    def known_pair?(db, pair)
      file, code, *rest = pair.downcase.split(PAIR_SEPARATOR, -1)
      rest.empty? &&
        known_keywords(db, dm.file_provenance_types_vocab).include?(file) &&
        known_keywords(db, dm.code_provenance_types_vocab).include?(code)
    end

    # The concept codes of the vocabularies, in lower case.
    def known_keywords(db, vocabularies)
      dm.concept_codes(db, vocabularies).map(&:downcase)
    end

    def all_provenance_types_vocab
      [ dm.file_provenance_types_vocab, dm.code_provenance_types_vocab ].flatten
    end

    def prov_of(db, vocabularies, ancestors)
      dm.descendants_of(db, dm.concept_ids(db, vocabularies, ancestors))
    end

    def plain_condition(db, codes)
      Sequel.|(
        { file_provenance_type: prov_of(db, all_provenance_types_vocab, codes) },
        { code_provenance_type: prov_of(db, all_provenance_types_vocab, codes) }
      )
    end

    # An invalid pair (validation reports it) still builds a condition. A
    # half with no concept matches nothing, so the pair keeps no record.
    def pair_condition(db, pair)
      file, code = pair.split(PAIR_SEPARATOR, 2)
      Sequel.&(
        { file_provenance_type: prov_of(db, dm.file_provenance_types_vocab, [ file ]) },
        { code_provenance_type: prov_of(db, dm.code_provenance_types_vocab, [ code ]) }
      )
    end
  end
end
