require "active_support/concern"

module ConceptQL
  module Behaviors
    module Utilizable
      extend ActiveSupport::Concern
      include ConceptQL::Behaviors::Windowable

      included do
        domains :condition_occurrence
        category "Select by Property"
        basic_type :selection
        validate_no_upstreams
        validate_no_arguments

        require_column :length_of_stay
        require_column :admission_source
        require_column :discharge_location
      end

      def query(db)
        return db[:condition_occurrence].limit(1).nullify if omopv4_plus?
        return gdm_it(db)
      end

      def collection_type
        raise NotImplementedError
      end

      def gdm_it(db)
        ancestor_ids = lexicon.concepts("JIGSAW_FILE_PROVENANCE_TYPE", collection_type).select(:id)
        descendant_ids = lexicon.descendants_of(ancestor_ids).select_map(:descendant_id)
        primary_ids = lexicon.concepts("JIGSAW_CODE_PROVENANCE_TYPE", "primary").select_map(:id)

        primary_concepts = db[:clinical_codes].from_self(alias: :pcc)
          .join(:contexts, { Sequel[:pcn][:id] => Sequel[:pcc][:context_id] }, table_alias: :pcn)
          .join(:concepts, { Sequel[:pco][:id] => Sequel[:pcc][:clinical_code_concept_id] }, table_alias: :pco)
          .where(provenance_concept_id: primary_ids)
          .select(Sequel[:pcn][:collection_id], Sequel[:pco][:concept_code], Sequel[:pco][:vocabulary_id])


        db[:collections].from_self(alias: :cl)
          .join(:admission_details, { Sequel[:ad][:id] => Sequel[:cl][:admission_detail_id] }, table_alias: :ad)
          .left_join(:contexts, { Sequel[:cn][:collection_id] => Sequel[:cl][:id] }, table_alias: :cn)
          .left_join(:concepts, { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
          .left_join(:concepts, { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
          .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[:cl][:id] }, table_alias: :pcon)
          .where(Sequel[:cn][:source_type_concept_id] => descendant_ids)
      end

      def table
        :collections
      end

      def override_columns
        {
          start_date: Sequel[:ad][:admission_date].as(:start_date),
          end_date: Sequel[:ad][:discharge_date].as(:end_date),
          length_of_stay: ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1).as(:length_of_stay),
          admission_source: Sequel[:asc][:concept_code].as(:admission_source),
          discharge_location: Sequel[:dlc][:concept_code].as(:discharge_location),
          source_value: Sequel[:pcon][:concept_code].as(:source_value),
          source_vocabulary_id: Sequel[:pcon][:vocabulary_id].as(:source_vocabulary_id),
          person_id: Sequel[:cl][:patient_id].as(:person_id),
          criterion_id: Sequel[:cl][:id].as(:criterion_id),
          criterion_table: Sequel.cast_string("collections").as(:criterion_table),
          criterion_domain: Sequel.cast_string("condition_occurrence").as(:criterion_domain)
        } if gdm?
      end
    end
  end
end
