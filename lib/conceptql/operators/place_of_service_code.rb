require_relative 'operator'

module ConceptQL
  module Operators
    # Represents a operator that will grab all person rows that match the given place_of_service_codes
    #
    # PlaceOfServiceCode parameters are passed in as a set of strings.  Each string represents
    # a single place_of_service_code.  The place_of_service_code string must match one of the values in the
    # concept_name column of the concept table.  If you misspell the place_of_service_code name
    # you won't get any matches
    class PlaceOfServiceCode < Operator
      register __FILE__

      argument :places_of_service, type: :codelist, vocab: 'Place of Service'
      domains :visit_occurrence
      category "Select by Property"
      basic_type :selection

      query_columns :visit_occurrence, :concept
      validate_no_upstreams
      validate_at_least_one_argument

      def query_cols
        table_columns(*tables)
      end

      def domains
        if oi_cdm?
          [:condition_occurrence]
        else
          [:visit_occurrence]
        end
      end

      def table
        if oi_cdm?
          :clinical_codes
        else
          :visit_occurrence
        end
      end

      def query(db)
        if oi_cdm?
          pos_concepts = db.from(:concepts)
                            .where(vocabulary_id: ['Visit', 'Place of Service'], concept_code: arguments.map(&:to_s))
                            .select(:id)
          contexts = db.from(:contexts)
                       .where(pos_concept_id: pos_concepts)
                       .select(:id)
          db.from(:clinical_codes)
            .where(context_id: contexts)
        else
          db.from(:visit_occurrence___v)
            .join(:concept___c, { c__concept_id: pos_concept_column  })
            .where(c__concept_code: arguments.map(&:to_s))
            .where(c__vocabulary_id: 14)
        end
      end

      private

      def pos_concept_column
        return Sequel.cast(:v__visit_source_concept_id, :bigint) unless omopv4?
        Sequel.cast(:v__place_of_service_concept_id, :bigint)
      end
    end
  end
end
