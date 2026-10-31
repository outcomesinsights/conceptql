# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    # Filters the incoming stream of records to only those whose place of
    # service is one of the given codes of the CMS Place of Service
    # vocabulary.
    #
    # A record's place of service is pos_concept_id: a column of the record's
    # context in gdm and of observations in gdm_wide. The PoS query modifiers
    # bring it into the stream as visit_source_concept_id.
    #
    # If the record has NULL for its place of service, it is filtered out.
    #
    # Multiple places of service can be specified at once. Each code becomes
    # a concept ID through the lexicon, so a code that names no concept can
    # match no record. Such a code is an error, as an unrecognized
    # provenance keyword is.
    class PlaceOfServiceFilter < Operator
      register __FILE__

      VOCABULARY_ID = "CMS Place of Service"

      desc "Passes along records that match one or more of the Medicare Place Of Service values."

      argument :places_of_service, type: :codelist, vocab: VOCABULARY_ID
      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      validate_at_least_one_argument
      require_column :visit_source_concept_id
      default_query_columns

      def query(db)
        db.from(stream.evaluate(db))
          .where(visit_source_concept_id: place_of_service_concept_ids(db))
      end

      private

      def place_of_service_concept_ids(db)
        dm.concept_ids(db, VOCABULARY_ID, arguments.map(&:to_s))
      end

      # With no lexicon there are no codes to check against, and every code
      # would be reported. Provenance skips its check in the same situation.
      def additional_validation(db, _opts = {})
        return if dm.lexicon.strategy == :no_db

        known = dm.concept_codes(db, VOCABULARY_ID).map(&:downcase)
        unknown = arguments.reject { |code| known.include?(code.to_s.downcase) }
        add_error(UNKNOWN_CODE, *unknown) unless unknown.empty?
      end
    end
  end
end
