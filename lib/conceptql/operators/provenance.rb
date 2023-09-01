require_relative 'operator'
require_relative '../behaviors/provenanceable'

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
    # Multiple provenances can be specified at once
    class Provenance < Operator
      register __FILE__

      desc "Passes along records with the indicated provenance (e.g. inpatient, outpatient, file type)."

      argument :provenance_types, label: 'Provenance Types', type: :codelist
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

      def additional_validation(db, opts = {})
        bad_keywords = find_bad_keywords(db, arguments)
        if bad_keywords.present?
          add_error("unrecognized keywords", *(bad_keywords.uniq))
        end
      end
    end
  end
end


