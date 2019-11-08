require_relative "base"

module ConceptQL
  module Operators
    # Represents a operator that will grab all person rows that match the given place_of_service_codes
    #
    # PlaceOfServiceCode parameters are passed in as a set of strings.  Each string represents
    # a single place_of_service_code.  The place_of_service_code string must match one of the values in the
    # concept_name column of the concept table.  If you misspell the place_of_service_code name
    # you won't get any matches
    class PlaceOfServiceCode < Base
      register __FILE__

      argument :places_of_service, type: :codelist, vocab: 'Place of Service'
      domains :visit_occurrence
      category "Select by Property"
      basic_type :selection

      query_columns :visit_occurrence, :concept
      validate_no_upstreams
      validate_at_least_one_argument
      deprecated replaced_by: "place_of_service_filter"

      def query_cols
        dm.table_columns(*tables)
      end

      def domains(db)
        if gdm?
          [:condition_occurrence]
        else
          [:visit_occurrence]
        end
      end

      def table
        if gdm?
          :clinical_codes
        else
          :visit_occurrence
        end
      end

      def query(db)
        if gdm?
          pos_concepts = db.from(:concepts)
                            .where(vocabulary_id: ['Visit', 'Place of Service'], concept_code: arguments.map(&:to_s))
                            .select(:id)
          contexts = db.from(:contexts)
                       .where(pos_concept_id: pos_concepts)
                       .select(:id)
          db.from(:clinical_codes)
            .where(context_id: contexts)
        else
          db.from(Sequel[:visit_occurrence].as(:v))
            .join(Sequel[:concept].as(:c), concept_id: pos_concept_column)
            .where(Sequel[:c][:concept_code] => arguments.map(&:to_s))
            .where(Sequel[:c][:vocabulary_id] => 14)
        end
      end

      private

      def pos_concept_column
        return Sequel.cast(Sequel[:v][:visit_source_concept_id], :bigint) unless omopv4?
        Sequel.cast(Sequel[:v][:place_of_service_concept_id], :bigint)
      end
    end
  end
end
