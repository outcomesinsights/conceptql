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
    module Formats
      class << self
        # The anchored pattern of a vocabulary as a string, or nil. The lookup
        # ignores case.
        def pattern(vocabulary_id)
          patterns[vocabulary_id.to_s.downcase]
        end

        # The anchored pattern as a case-insensitive Regexp, or nil.
        def regexp(vocabulary_id)
          (str = pattern(vocabulary_id)) && Regexp.new(str, Regexp::IGNORECASE)
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
