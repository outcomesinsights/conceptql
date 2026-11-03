# frozen_string_literal: true

require_relative "operator"
require_relative "../behaviors/provenanceable"

module ConceptQL
  module Operators
    # Filters the incoming stream of records to only those that have a
    # provenance-related concept_id.
    #
    # Provenance related concepts are the ones found in the xxx_type_concept_id
    # field.
    #
    # If the record has NULL for the provenance-related field, they are filtered
    # out.
    #
    # Multiple provenances can be specified at once. "*" asks for any
    # provenance. At least one keyword is required.
    class Provenance < Operator
      register __FILE__

      desc "Passes along the records whose provenance matches at least one of the given keywords. " \
           "The provenance of a record says which kind of file it came from, such as inpatient, " \
           "and where its code was on the claim, such as primary."

      returns "The upstream records whose provenance matches at least one of the keywords."

      argument :provenance_types, label: "Provenance Types", type: :codelist,
                                  meaning: "One or more provenance keywords, in lower case. " \
                                           "A file keyword, such as inpatient, outpatient or carrier_claim, says which kind of file a record came from. " \
                                           "A code keyword, such as primary or first, says where the code was on the claim. " \
                                           "A plain keyword matches a record when its file provenance or its code provenance matches it. " \
                                           "A keyword also matches the provenances under it, so inpatient includes snf. " \
                                           "A keyword of the form file:code, such as inpatient:primary, needs both the file and the code provenance to match. " \
                                           "The keyword * matches a record that has any provenance. " \
                                           "A statement with no keyword, or with an unknown keyword, is invalid."

      example "Diabetes diagnoses (ICD-9 250.00) from inpatient files",
              [ "provenance", "inpatient", [ "icd9", "250.00" ] ]

      category "Filter Single Stream"
      basic_type :temporal
      allows_one_upstream
      validate_one_upstream
      default_query_columns

      include ConceptQL::Provenanceable

      attr_reader :db

      def query(db)
        @db = db
        db.from(stream.evaluate(db)).where(build_where_from_codes(db, arguments))
      end

      private

      def additional_validation(db, _opts = {})
        return add_error('no provenance keywords; use "*" for any provenance') if arguments.empty?

        # With no lexicon there are no provenance concepts to check against,
        # and every keyword would be reported as unrecognized. Vocabulary
        # operators skip their unknown-code check in the same situation.
        return if dm.lexicon.strategy == :no_db

        bad_keywords = find_bad_keywords(db, arguments)
        return unless bad_keywords.present?

        add_error("unrecognized keywords", *bad_keywords.uniq)
      end
    end
  end
end
