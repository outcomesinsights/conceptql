require_relative 'operator'

module ConceptQL
  module Operators
    class Utilization < Operator
      include ConceptQL::Behaviors::Windowable

      domains :condition_occurrence
      category "Select by Property"
      basic_type :selection
      validate_no_upstreams
      validate_no_arguments

      require_column :length_of_stay
      require_column :admission_source
      require_column :discharge_location

      def query(db)
        return db.dataset.nullify if omopv4_plus?
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
          .where(collection_type_concept_id: descendant_ids)
          .select(*select_columns)
          .from_self
      end

      def select_columns
        [
          Sequel[:ad][:admission_date].as(:start_date),
          Sequel[:ad][:discharge_date].as(:end_date),
          ((rdbms.days_between(Sequel[:ad][:admission_date], Sequel[:ad][:discharge_date])) + 1).as(:length_of_stay),
          Sequel[:asc][:concept_code].as(:admission_source),
          Sequel[:dlc][:concept_code].as(:discharge_location),
          Sequel[:pcon][:concept_code].as(:source_value),
          Sequel[:pcon][:vocabulary_id].as(:source_vocabulary_id)
        ]
      end

      def table
        :collections
      end

      def override_columns
        required_columns.zip(required_columns).to_h
      end
    end
  end
end

