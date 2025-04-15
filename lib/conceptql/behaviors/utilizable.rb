# frozen_string_literal: true

require 'active_support/concern'

module ConceptQL
  module Behaviors
    module Utilizable
      extend ActiveSupport::Concern
      include ConceptQL::Behaviors::Windowable

      included do
        domains :condition_occurrence
        category 'Select by Property'
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

        gdm_it(db)
      end

      def collection_type
        raise NotImplementedError
      end

      def gdm_it(db)
        source_type_id = dm.concept_ids(db, dm.file_provenance_types_vocab, collection_type)
        all_source_type_ids = dm.descendants_of(db, source_type_id)
        primary_id = dm.concept_ids(db, dm.code_provenance_types_vocab, 'primary')
        all_primary_ids = dm.descendants_of(db, primary_id)
        # condition_vocabularies = dm.vocabularies_query.where(domain: 'condition_occurrence').select_map(:id)

        return gdm_wide_it(db, all_primary_ids, all_source_type_ids) if wide?

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

      def gdm_wide_it(db, all_primary_ids, all_source_type_ids)
        # TODO: Reinstate the original, less clunky version of this change once we stop
        # supporting Spark 3.3.x
        primary_cases = {}
        all_primary_ids.each do |primary_id|
          primary_cases[Sequel[:provenance_concept_id] => primary_id] = 1
        end

        # This generates some gnarly SQL if there are no primary cases (like when we run a statement without a database to grab concepts from)
        is_primary = Sequel[0]
        is_primary = Sequel.case(primary_cases, 0) unless primary_cases.empty?

        db[:observations]
          .where({
                   source_type_concept_id: all_source_type_ids
                 }).
                 exclude(admit_admission_date: nil)
          .select_append(
            is_primary.as(:is_primary)
          )
          .from_self
          .select_append(Sequel[:ROW_NUMBER].function.over(
            partition: [:patient_id, :admit_admission_date, :admit_discharge_date],
            order: [Sequel[:is_primary].desc, Sequel[:collection_id], Sequel[:clinical_code_concept_id]]
          ).as(:nummy))
          .from_self
          .where(nummy: 1)
          .from_self
          .left_join(dm.concepts_table(db), { Sequel[:admit_source_concept_id] => Sequel[:asc][:id] }, table_alias: :asc)
          .left_join(dm.concepts_table(db), { Sequel[:discharge_location_concept_id] => Sequel[:dlc][:id] }, table_alias: :dlc)
          .select_append(
            Sequel[:asc][:concept_code].as(:admission_source_value),
            Sequel[:asc][:concept_text].as(:admission_source_description),
            Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
            Sequel[:dlc][:concept_text].as(:discharge_location_source_description),
            Sequel.case({ 1 => :clinical_code_source_value }, nil, :is_primary).as(:source_value),
            Sequel.case({ 1 => :clinical_code_vocabulary_id }, nil, :is_primary).as(:source_vocabulary_id)
          )
          .from_self
      end

      def table
        :collections
      end

      def override_columns
        return unless gdm?

        if wide?
          {
            length_of_stay: (rdbms.days_between(Sequel[:admit_admission_date],
                                                Sequel[:admit_discharge_date]) + 1).as(:length_of_stay),
            criterion_table: Sequel.cast_string('collections').as(:criterion_table),
            criterion_domain: Sequel.cast_string('condition_occurrence').as(:criterion_domain),
            admission_source_value: Sequel[:admission_source_value],
            admission_source_description: Sequel[:admission_source_description],
            discharge_location_source_value: Sequel[:discharge_location_source_value],
            discharge_location_source_description: Sequel[:discharge_location_source_description],
            admission_date: Sequel[:admission_date],
            discharge_date: Sequel[:discharge_date],
            person_id: Sequel[:patient_id].as(:person_id),
            criterion_id: Sequel[:collection_id].as(:criterion_id),
            start_date: Sequel[:collection_start_date].as(:start_date),
            end_date: Sequel[:collection_end_date].as(:end_date),
            source_value: Sequel[:source_value].as(:source_value),
            source_vocabulary_id: Sequel[:source_vocabulary_id].as(:source_vocabulary_id)
          }
        else
          {
            start_date: Sequel[:cl][:start_date].as(:start_date),
            end_date: Sequel[:cl][:end_date].as(:end_date),
            admission_date: Sequel[:ad][:admission_date],
            discharge_date: Sequel[:ad][:discharge_date],
            length_of_stay: (rdbms.days_between(Sequel[:ad][:admission_date],
                                                Sequel[:ad][:discharge_date]) + 1).as(:length_of_stay),
            admission_source_value: Sequel[:asc][:concept_code].as(:admission_source_value),
            admission_source_description: Sequel[:asc][:concept_text].as(:admission_source_description),
            discharge_location_source_value: Sequel[:dlc][:concept_code].as(:discharge_location_source_value),
            discharge_location_source_description: Sequel[:dlc][:concept_text].as(:discharge_location_source_description),
            source_value: Sequel[:pcon][:concept_code].as(:source_value),
            source_vocabulary_id: Sequel[:pcon][:vocabulary_id].as(:source_vocabulary_id),
            person_id: Sequel[:cl][:patient_id].as(:person_id),
            criterion_id: Sequel[:cl][:id].as(:criterion_id),
            criterion_table: Sequel.cast_string('collections').as(:criterion_table),
            criterion_domain: Sequel.cast_string('condition_occurrence').as(:criterion_domain)
          }
        end
      end
    end
  end
end
