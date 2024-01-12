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

        require_column :admission_date
        require_column :discharge_date
        require_column :length_of_stay
        require_column :admission_source_value
        require_column :admission_source_description
        require_column :discharge_location_source_value
        require_column :discharge_location_source_description
      end

      def query(db)
        return db[:condition_occurrence].where(false) if omopv4_plus?
        return gdm_it(db)
      end

      def collection_type
        raise NotImplementedError
      end

      def gdm_it(db)
        source_type_id = dm.concept_ids(db, dm.file_provenance_types_vocab, collection_type)
        all_source_type_ids = dm.descendants_of(db, source_type_id)
        primary_id = dm.concept_ids(db, dm.code_provenance_types_vocab, "primary")
        all_primary_ids = dm.descendants_of(db, primary_id)
        #condition_vocabularies = dm.vocabularies_query.where(domain: 'condition_occurrence').select_map(:id)

        if wide?
          return db[:observations]
            .where({
              provenance_concept_id: all_primary_ids,
              source_type_concept_id: all_source_type_ids
            })
            .left_join(dm.concepts_table(db), { Sequel[:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
            .left_join(dm.concepts_table(db), { Sequel[:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
            .select_append(
              Sequel[:asc][:concept_code].as(:admission_source_value),
              Sequel[:asc][:concept_text].as(:admission_source_description),
              Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
              Sequel[:dlc][:concept_text].as(:discharge_location_source_description)
            )
            .from_self
        end

        # Get primary diagnosis codes
        primary_concepts = rdbms.primary_concepts(db, all_primary_ids)

        relevant_contexts = db[Sequel[:contexts].as(:cn)]
          .where(Sequel[:cn][:source_type_concept_id] => all_source_type_ids)
          .select(:collection_id)

        db[:collections].from_self(alias: :cl)
          .join(:admission_details, { Sequel[:ad][:id] => Sequel[:cl][:admission_detail_id] }, table_alias: :ad)
          .left_join(dm.concepts_table(db), { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
          .left_join(dm.concepts_table(db), { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
          .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[:cl][:id] }, table_alias: :pcon)
          .where(Sequel[:cl][:id] => relevant_contexts)
      end

      def table
        :collections
      end

      def override_columns
        if gdm?
          if wide?
            {
              length_of_stay: ((rdbms.days_between(Sequel[:admit_admission_date], Sequel[:admit_discharge_date])) + 1).as(:length_of_stay),
              criterion_table: Sequel.cast_string("collections").as(:criterion_table),
              criterion_domain: Sequel.cast_string("condition_occurrence").as(:criterion_domain),
              admission_source_value: Sequel[:admission_source_value],
              admission_source_description: Sequel[:admission_source_description],
              discharge_location_source_value: Sequel[:discharge_location_source_value],
              discharge_location_source_description: Sequel[:discharge_location_source_description],
              admission_date: Sequel[:admission_date],
              discharge_date: Sequel[:discharge_date]
            }
          else
            {
              start_date: Sequel[:cl][:start_date].as(:start_date),
              end_date: Sequel[:cl][:end_date].as(:end_date),
              admission_date: Sequel[:ad][:admission_date],
              discharge_date: Sequel[:ad][:discharge_date],
              length_of_stay: ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1).as(:length_of_stay),
              admission_source_value: Sequel[:asc][:concept_code].as(:admission_source_value),
              admission_source_description: Sequel[:asc][:concept_text].as(:admission_source_description),
              discharge_location_source_value: Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
              discharge_location_source_description: Sequel[:dlc][:concept_text].as(:discharge_location_source_description),
              source_value: Sequel[:pcon][:concept_code].as(:source_value),
              source_vocabulary_id: Sequel[:pcon][:vocabulary_id].as(:source_vocabulary_id),
              person_id: Sequel[:cl][:patient_id].as(:person_id),
              criterion_id: Sequel[:cl][:id].as(:criterion_id),
              criterion_table: Sequel.cast_string("collections").as(:criterion_table),
              criterion_domain: Sequel.cast_string("condition_occurrence").as(:criterion_domain)
            }
          end
        end
      end
    end
  end
end
