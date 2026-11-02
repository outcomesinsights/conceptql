# frozen_string_literal: true

module ConceptQL
  # A code lookup got codes that match no stored code exactly, but match a
  # stored code of the same vocabulary when case is ignored (bead
  # conceptql-rz8s). ConceptQL compares codes case-exactly (seed conceptql-oji
  # ruling "b"), so without this error the lookup returns no concept for those
  # codes, and the caller loses rows without a word. t_shank asked GDM_PROV for
  # "line" when the vocabulary stores "LINE".
  #
  # The public lookups of ConceptQL::Lexicon (and of the DataModel, which
  # delegates to it) raise it. A vocabulary operator in a statement does not:
  # it passes check_case: false, and warns about the code instead.
  class CodeCaseMismatchError < ArgumentError
    # One code of one vocabulary. +stored+ is every spelling of the code that
    # the vocabulary stores, sorted.
    Mismatch = Data.define(:vocabulary_id, :code, :stored) do
      def to_s
        "The vocabulary #{vocabulary_id} stores #{code.inspect} as #{stored.map(&:inspect).join(" or ")}."
      end
    end

    attr_reader :mismatches

    def initialize(mismatches)
      @mismatches = mismatches
      super([
        "A code lookup got codes that their vocabulary stores only in another case.",
        "ConceptQL compares codes case-exactly, so these codes would match no concept:",
        *mismatches.map { |mismatch| "  - #{mismatch}" },
        "Pass each code as its vocabulary stores it."
      ].join("\n"))
    end

    # The mismatches among +codes+, given +rows+: the [vocabulary_id,
    # concept_code] pairs of the vocabularies' codes that equal one of the
    # codes when case is ignored. A code that some vocabulary stores exactly
    # is no mismatch. Neither is a code that no vocabulary stores in any case.
    def self.mismatches(codes, rows)
      codes.map(&:to_s).uniq.flat_map do |code|
        same = rows.select { |_, stored| stored.casecmp?(code) }
        next [] if same.empty? || same.any? { |_, stored| stored == code }

        same.group_by(&:first).sort.map do |vocabulary_id, pairs|
          Mismatch.new(vocabulary_id, code, pairs.map(&:last).uniq.sort)
        end
      end
    end
  end
end
