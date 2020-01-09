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
        require_column :admission_source
        require_column :discharge_location
      end

      def query(db)
        return db[:condition_occurrence].where(false) if omopv4_plus?
        return gdm_it(db)
      end

      def collection_type
        raise NotImplementedError
      end

      def gdm_it(db)
        source_type_id = lexicon.concepts("JIGSAW_FILE_PROVENANCE_TYPE", collection_type).select_map(:id)
        all_source_type_ids = lexicon.descendants_of(source_type_id).select_map(:descendant_id)
        primary_id = lexicon.concepts("JIGSAW_CODE_PROVENANCE_TYPE", "primary").select_map(:id)
        all_primary_ids = lexicon.descendants_of(primary_id).select_map(:descendant_id)
        condition_domains = lexicon.lexicon_db[:vocabularies].where(domain: 'condition_occurrence').select_map(:id)

        # Get primary diagnosis codes
        primary_concepts = db[Sequel[:clinical_codes].as(:pcc)]
          .where(provenance_concept_id: all_primary_ids, Sequel[:pcc][:clinical_code_vocabulary_id] => condition_domains)
          .select(
            Sequel[:pcc][:collection_id].as(:collection_id),
            Sequel[:pcc][:clinical_code_source_value].as(:concept_code),
            Sequel[:pcc][:clinical_code_vocabulary_id].as(:vocabulary_id))
          .order(Sequel[:pcc][:collection_id], Sequel[:pcc][:clinical_code_concept_id])
          .from_self
          .distinct(:collection_id)


        db[:collections].from_self(alias: :cl)
          .join(:admission_details, { Sequel[:ad][:id] => Sequel[:cl][:admission_detail_id] }, table_alias: :ad)
          .left_join(:contexts, { Sequel[:cn][:collection_id] => Sequel[:cl][:id] }, table_alias: :cn)
          .left_join(:concepts, { Sequel[:ad][:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
          .left_join(:concepts, { Sequel[:ad][:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
          .left_join(primary_concepts, { Sequel[:pcon][:collection_id] => Sequel[:cl][:id] }, table_alias: :pcon)
          .where(Sequel[:cn][:source_type_concept_id] => all_source_type_ids)
      end

      def table
        :collections
      end

      def override_columns
        {
          start_date: Sequel[:cl][:start_date].as(:start_date),
          end_date: Sequel[:cl][:end_date].as(:end_date),
          admission_date: Sequel[:ad][:admission_date],
          discharge_date: Sequel[:ad][:discharge_date],
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
