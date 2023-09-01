require_relative "base"

module ConceptQL
  module DataModel
    class Gdm < Base

      def query_modifier_for(column)
        {
          visit_source_concept_id: ConceptQL::QueryModifiers::Gdm::PoSQueryModifier,
          provider_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          specialty_concept_id: ConceptQL::QueryModifiers::Gdm::ProviderQueryModifier,
          drug_name: ConceptQL::QueryModifiers::Gdm::DrugQueryModifier,
          admission_date: ConceptQL::QueryModifiers::Gdm::AdmissionDateQueryModifier,
          provenance_type: ConceptQL::QueryModifiers::Gdm::ProvenanceQueryModifier,
          value_as_number: ConceptQL::QueryModifiers::Gdm::LabQueryModifier,
        }[column]
      end

      def make_table_id
        :id
      end

      def person_id(table = nil)
        return :id if table == :patients
        :patient_id
      end

      def person_table
        :patients
      end

      def period_table
        :information_periods
      end

      def criterion_id
        Sequel.expr(:id).as(:criterion_id)
      end

      def table_id(table = nil)
        return :criterion_id if table.nil?
        Sequel.expr(make_table_id(table)).as(:criterion_id)
      end

      def make_table_id(table)
        :id
      end

      def fk_by_domain(domain)
        table = table_by_domain(domain)
        (table.to_s.gsub(/_id/, "").chomp("s") + "_id").to_sym
      end

      def pk_by_domain(domain)
        :id
      end

      def table_by_domain(table)
        return nil unless table
        case table
        when :person, :patients
          :patients
        when :death, :deaths
          :deaths
        when :observation_period, :information_periods
          :information_periods
        when :provider, :practitioners
          :practitioners
        when :collections
          :collections
        else
          :clinical_codes
        end
      end

      def table_to_domain(table)
        {
          patients: :person,
          deaths: :death,
          information_periods: :observation_period,
          practitioners: :provider
        }[table]
      end

      def person_id_column(table)
        col = if table.to_sym == :patients
          :id
        else
          :patient_id
        end
        Sequel.identifier(col).as(:person_id)
      end

      def data_model
        :gdm
      end

      def start_date_column(query, domain)
        start_date_columns[domain]
      end

      def end_date_column(query, domain)
        end_date_columns[domain]
      end

      def id_column(table)
        :id
      end

      def pos_table_fk
        :context_id
      end

      def source_vocabulary_ids
        @source_vocabulary_ids = assign_column_to_table do |table, columns|
          next if %w(patients death).any? { |tn| table.to_s =~ /#{tn}/ }
          reggy = /#{table.to_s.split("_").first}_vocabulary_id/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /_vocabulary_id/ }.first
        end
      end

      def concepts(db, vocabulary_id, codes = [])
        ds = concepts_table(db)

        ds = ds.where(vocabulary_id: vocabulary_id) unless vocabulary_id == "*"
        ds = ds.where(Sequel.function(:lower, :concept_code) => Array(codes).map(&:downcase)) unless codes.blank?

        ds
      end

      def concepts_by_name(db, names = [])
        ds = concepts_table(db)

        ds = ds.where(Sequel.function(:lower, :concept_text) => Array(names).map(&:downcase))

        ds
      end

      def descendants_of(db, concept_ids_or_ds)
        where_values = Array(concept_ids_or_ds).flatten.dup

        descendants = ancestors_table(db)
          .where(ancestor_id: where_values)
          .select(:descendant_id)

        unless where_values.empty?
          union_clause = db.values(where_values.map { |v| [v] })
          descendants = descendants.union(union_clause).distinct
        end

        descendants.select_map(:descendant_id)
      end

      def concept_ids(db, vocabulary_id, codes = [])
        concepts(db, vocabulary_id, codes).select_map(:id)
      end

      # The mappings table will tell us what other concepts have been directly
      # mapped to the concepts passed in
      def related_concept_ids(db, *ids)
        ids = ids.flatten
        other_ids = is_a_relationships(db).where(concept_2_id: ids).select_map(:concept_1_id)
        other_ids + ids
      end

      def is_a_relationships(some_db)
        if some_db.table_exists?(:concept_relationship)
          concept_relationship_to_mappings(some_db).where{Sequel.function(:lower, :relationship_id) =~ 'is a'}
        else
          some_db[:mappings].where{Sequel.function(:lower, :relationship_id) =~ 'is_a'}
        end
      end

      def concept_relationship_to_mappings(some_db)
        some_db[:concept_relationship]
          .select(
            Sequel[:concept_id_1].as(:concept_1_id),
            Sequel[:concept_id_2].as(:concept_2_id),
            :relationship_id
          ).from_self
      end

      def ancestors_table(some_db)
        if some_db.table_exists?(:concept_ancestor)
          some_db[:concept_ancestor].select(
            Sequel[:ancestor_concept_id].as(:ancestor_id),
            Sequel[:descendant_concept_id].as(:descendant_id)
          ).from_self
        else
          some_db[:ancestors]
        end
      end

      def concepts_table(some_db, some_schema = nil)
        if some_db.table_exists?(:concept)
          concept_to_concepts_table(some_db, some_schema)
        else
          concepts_to_concepts_table(some_db, some_schema)
        end
      end

      def concept_to_concepts_table(some_db, some_schema = nil)
        table_name = :concept

        if some_schema
          table_name = Sequel.qualify(some_schema, table_name)
        end

        some_db[table_name].select(
          Sequel[:concept_id].as(:id),
          :concept_code,
          :vocabulary_id,
          Sequel[:concept_name].as(:concept_text)
        ).from_self
      end

      def concepts_to_concepts_table(some_db, some_schema = nil)
        table_name = :concepts

        if some_schema
          table_name = Sequel.qualify(some_schema, table_name)
        end

        some_db[table_name]
      end

      def table_is_missing?(db)
        !(db.table_exists?(:concepts) || db.table_exists?(:concept))
      end

      def db_is_mock?(db)
        db.is_a?(Sequel::Mock::Database)
      end

      def code_provenance_type(query, domain)
        :provenance_concept_id
      end

      def file_provenance_type(query, domain)
        :source_type_concept_id
      end

      def known_codes(db, vocabulary_id, codes)
        return codes if db_is_mock?(db)
        return codes if vocabulary_is_empty?(db, vocabulary_id)
        concepts_ds(db, vocabulary_id, codes).select_map(:concept_code)
      rescue Sequel::DatabaseError
        []
      end

      def concepts_to_codes(db, vocabulary_id, codes = [])
        if db.nil? || table_is_missing?(db)
          return codes.map { |code| [code, nil]}
        end
        concepts(db, vocabulary_id, codes).select_map([:concept_code, :concept_text])
      end

      def vocabulary_is_empty?(db, vocabulary_id)
        concepts_table(db).where(vocabulary_id: vocabulary_id).count.zero?
      end

      def concepts_ds(db, vocabulary_id, codes)
        concepts_table(db)
          .where(vocabulary_id: vocabulary_id, concept_code: codes)
          .select(Sequel[:concept_code].as(:concept_code), Sequel[:concept_text].as(:concept_text))
          .from_self
      end

      def information_period_where_clause(arguments)
        return if arguments.empty?
        { information_type_concept_id: arguments.map(&:to_i) }
      end

      def file_provenance_types_vocab
        ["JIGSAW_FILE_PROVENANCE_TYPE", "JS_FILE_PROV_TYPE"]
      end

      def code_provenance_types_vocab
        ["JIGSAW_CODE_PROVENANCE_TYPE", "JS_CODE_PROV_TYPE"]
      end
    end
  end
end
