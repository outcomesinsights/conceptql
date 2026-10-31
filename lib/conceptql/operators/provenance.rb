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
           "Each record has a file provenance, such as inpatient or outpatient, " \
           "and a code provenance, such as primary or first. " \
           "A plain keyword matches a record when either provenance matches it. " \
           "A keyword of the form <file keyword>:<code keyword> matches a record when its file provenance " \
           "matches the file keyword and its code provenance matches the code keyword. " \
           "The keyword * matches a record that has any file or code provenance. " \
           "At least one keyword is required."

      argument :provenance_types, label: "Provenance Types", type: :codelist
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
