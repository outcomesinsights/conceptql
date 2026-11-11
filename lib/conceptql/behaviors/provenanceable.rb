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
  #
  # The keyword "*" keeps a record when either column is any provenance
  # concept. Because keywords are ORed, "*" with other keywords is "*".
  module Provenanceable
    PAIR_SEPARATOR = ":"
    ANY = "*"

    def self.included(base)
      base.require_column :file_provenance_type
      base.require_column :code_provenance_type
    end

    # No keyword at all is a validation error of Provenance. It still builds
    # the condition of "*", as an unknown pair still builds a condition.
    def build_where_from_codes(db, codes)
      return plain_condition(db, []) if codes.empty? || codes.include?(ANY)

      pairs, plain = codes.partition { |code| pair_keyword?(code) }
      conditions = pairs.map { |pair| pair_condition(db, pair) }
      conditions.unshift(plain_condition(db, plain)) if plain.any?
      return conditions.first if conditions.one?

      Sequel.|(*conditions)
    end

    # The keywords as written that the dataset's lexicon does not know, as
    # [not_present, unknown] in the order written (bead conceptql-amuu).
    # Database#check_codes sorts them with the 2020 rule, as it sorts the
    # codes of a vocabulary operator: a keyword that the reference lexicon
    # knows is not present in this dataset, and the rest are unknown.
    #
    # A plain keyword is checked against the file and the code provenance
    # vocabularies together. A pair is checked half by half: the file keyword
    # against the file vocabularies and the code keyword against the code
    # vocabularies. A pair with an unknown half is unknown, and else a pair
    # with a half that is not present is not present. A pair needs exactly
    # one separator, or it is unknown.
    #
    # Case is compared exactly, as the lookup compares it: the provenance
    # vocabularies have no vocabulary_formats row that declares
    # case-insensitivity (seed conceptql-oji ruling "b"). So "Inpatient" names
    # no concept, and the concept codes are in lower case. "*" is known. It is
    # not a half of a pair.
    def check_keywords(db, codes)
      pairs, plain = (codes.map(&:to_s).uniq - [ ANY ]).partition { |code| pair_keyword?(code) }
      not_present, unknown = check_codes(db, all_provenance_types_vocab, plain)
      pair_not_present, pair_unknown = check_pairs(db, pairs)
      [ not_present + pair_not_present, unknown + pair_unknown ].map do |bad|
        codes.select { |code| bad.include?(code.to_s) }.uniq
      end
    end

    private

    def pair_keyword?(code)
      code.to_s.include?(PAIR_SEPARATOR)
    end

    # [not_present, unknown] of the pairs.
    def check_pairs(db, pairs)
      halves = pairs.to_h { |pair| [ pair, pair.split(PAIR_SEPARATOR, -1) ] }
      malformed, formed = halves.partition { |_, parts| parts.size != 2 }.map(&:to_h)
      files_not_present, files_unknown = check_codes(db, dm.file_provenance_types_vocab, formed.values.map(&:first).uniq)
      codes_not_present, codes_unknown = check_codes(db, dm.code_provenance_types_vocab, formed.values.map(&:last).uniq)
      unknown = formed.select { |_, (file, code)| files_unknown.include?(file) || codes_unknown.include?(code) }.keys
      not_present = formed.select { |_, (file, code)| files_not_present.include?(file) || codes_not_present.include?(code) }.keys
      [ not_present - unknown, malformed.keys + unknown ]
    end

    # Database#check_codes, which is not asked about no codes.
    def check_codes(db, vocabularies, codes)
      return [ [], [] ] if codes.empty?

      nodifier.cdb.check_codes(db, vocabularies, codes)
    end

    def all_provenance_types_vocab
      [ dm.file_provenance_types_vocab, dm.code_provenance_types_vocab ].flatten
    end

    # The keywords come from the statement, whose validation warns about a
    # bad one (check_keywords), so the lookup does not raise
    # CodeCaseMismatchError. A keyword that names no concept selects nothing.
    def prov_of(db, vocabularies, ancestors)
      dm.descendants_of(db, dm.concept_ids(db, vocabularies, ancestors, check_case: false))
    end

    def plain_condition(db, codes)
      Sequel.|(
        { file_provenance_type: prov_of(db, all_provenance_types_vocab, codes) },
        { code_provenance_type: prov_of(db, all_provenance_types_vocab, codes) }
      )
    end

    # An unknown pair (validation warns about it) still builds a condition. A
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
