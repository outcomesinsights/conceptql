# frozen_string_literal: true

require "csv"
require_relative "../paths"

module ConceptQL
  module Vocabularies
    # The code formats that a Vocabulary operator checks its codes against.
    # They come from config/vocabulary_formats.tsv, a pinned copy of the
    # published table of the public repository
    # outcomesinsights/vocabulary_formats (bead conceptql-bns, seed
    # conceptql-ysx). config/vocabulary_formats.sha records the commit, and
    # `just vocabulary-formats <ref>` refreshes both.
    #
    # Only the DEFAULT row of a vocabulary is used: the row whose vocabulary_id
    # is the vocabulary's id. A variant row (ICD9CM.DOTLESS) is never used. The
    # published patterns carry no anchors, so each one is anchored here as
    # \A(?:pattern)\z. A vocabulary with no row has no format to check.
    #
    # A pattern is case-exact unless its row declares case-insensitivity with
    # the scoped flag (?i:...) (vocabulary_formats seed vfm-8k1, seed
    # conceptql-oji ruling "b"). Ruby honors the flag natively, so a pattern
    # is compiled with no flag of its own: an ignore-case flag would override
    # what the row says.
    module Formats
      DECLARES_CASE_INSENSITIVE = "(?i:"

      class << self
        # The anchored pattern of a vocabulary as a string, or nil. The
        # vocabulary_id finds its row in any case.
        def pattern(vocabulary_id)
          patterns[vocabulary_id.to_s.downcase]
        end

        # The anchored pattern as a Regexp, or nil.
        def regexp(vocabulary_id)
          (str = pattern(vocabulary_id)) && Regexp.new(str)
        end

        # True when the vocabulary's row declares case-insensitivity with
        # (?i:...). The lexicon then matches the vocabulary's codes without
        # regard to case (LexiconStrategy#code_condition). A vocabulary with no
        # row is case-exact.
        def case_insensitive?(vocabulary_id)
          pattern(vocabulary_id).to_s.include?(DECLARES_CASE_INSENSITIVE)
        end

        private

        def patterns
          @patterns ||= CSV.foreach(ConceptQL.vocabulary_formats_file_path, col_sep: "\t", headers: true)
                           .reject { |row| row["vocabulary_id"].include?(".") }
                           .to_h { |row| [ row["vocabulary_id"].downcase, "\\A(?:#{row.fetch("regexp")})\\z" ] }
                           .freeze
        end
      end
    end
  end
end
