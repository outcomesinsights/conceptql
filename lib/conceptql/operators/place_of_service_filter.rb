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
    #
    # The code "*" keeps a record whose place of service is any concept of
    # the vocabulary, as provenance's "*" keeps any provenance concept. A
    # pos_concept_id of another vocabulary is not a place of service. Because
    # codes are ORed, "*" with other codes is "*". The other codes are still
    # checked.
    class PlaceOfServiceFilter < Operator
      register __FILE__

      VOCABULARY_ID = "CMS Place of Service"
      ANY = "*"

      desc "Passes along the records whose place of service is one of the given CMS Place of Service codes. " \
           "A record that has no place of service is not passed along."

      returns "The upstream records whose place of service is one of the given codes."

      argument :places_of_service, type: :codelist, vocab: VOCABULARY_ID,
                                   meaning: "One or more CMS Place of Service codes, such as 21 (inpatient hospital) or 22 (outpatient hospital). " \
                                            "The code * matches a record whose place of service is any code of that vocabulary. " \
                                            "An unknown code makes the statement invalid."

      # The test data has no place of service, so the example returns no rows
      example "Diabetes diagnoses (ICD-9 250.00) with the place of service outpatient hospital (22)",
              [ "place_of_service_filter", 22, [ "icd9", "250.00" ] ], help: false

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

      # With no codes, the lookup returns every concept of the vocabulary.
      # The codes come from the statement, whose validation reports an
      # unknown code, so the lookup does not raise CodeCaseMismatchError.
      def place_of_service_concept_ids(db)
        codes = arguments.map(&:to_s)
        dm.concept_ids(db, VOCABULARY_ID, codes.include?(ANY) ? [] : codes, check_case: false)
      end

      # With no lexicon there are no codes to check against, and every code
      # would be reported. Provenance skips its check in the same situation.
      # A code is known only in its own case, as the lookup finds it.
      def additional_validation(db, _opts = {})
        return if dm.lexicon.strategy == :no_db

        known = dm.concept_codes(db, VOCABULARY_ID)
        unknown = arguments.reject { |code| code.to_s == ANY || known.include?(code.to_s) }
        add_error(UNKNOWN_CODE, *unknown) unless unknown.empty?
      end
    end
  end
end
