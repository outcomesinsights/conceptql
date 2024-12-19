# frozen_string_literal: true

module ConceptQL
  class LexiconStrategy
    attr_reader :db

    def initialize(db)
      @db = db
    end

    def concepts(_data_db, vocabulary_id, codes = [])
      ds = concepts_table(_data_db)

      ds = ds.where(vocabulary_id: vocabulary_id) unless vocabulary_id == '*'
      ds = ds.where(Sequel.function(:lower, :concept_code) => Array(codes).map(&:downcase)) unless codes.blank?

      ds
    end

    def concepts_by_name(_data_db, names = [])
      ds = concepts_table(_data_db)

      ds.where(Sequel.function(:lower, :concept_text) => Array(names).map(&:downcase))
    end

    def descendants_of(_data_db, concept_ids_or_ds)
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

    def concept_ids(_data_db, vocabulary_id, codes = [])
      concepts(db, vocabulary_id, codes)
        .select_map(:id)
    end

    # The mappings table will tell us what other concepts have been directly
    # mapped to the concepts passed in
    def related_concept_ids(_data_db, *ids)
      ids = ids.flatten
      other_ids = is_a_relationships(_data_db)
                  .where(concept_2_id: ids)
                  .select_map(:concept_1_id)
      other_ids + ids
    end

    def known_codes(_data_db, vocabulary_id, codes)
      return codes if db_is_mock?(_data_db)
      return codes if vocabulary_is_empty?(_data_db, vocabulary_id)

      concepts_ds(_data_db, vocabulary_id, codes).select_map(:concept_code)
    rescue Sequel::DatabaseError
      []
    end

    def concepts_to_codes(_data_db, vocabulary_id, codes = [])
      return codes.map { |code| [code, nil] } if db.nil? || table_is_missing?(_data_db)

      concepts(db, vocabulary_id, codes).select_map(%i[concept_code concept_text])
    end

    def vocabulary_is_empty?(_data_db, vocabulary_id)
      concepts_table(_data_db).where(vocabulary_id: vocabulary_id).count.zero?
    end

    def concepts_ds(_data_db, vocabulary_id, codes)
      concepts_table(_data_db)
        .where(vocabulary_id: vocabulary_id, concept_code: codes)
        .select(Sequel[:concept_code].as(:concept_code), Sequel[:concept_text].as(:concept_text))
        .from_self
    end

    def db_is_mock?(_data_db)
      db.is_a?(Sequel::Mock::Database)
    end
  end
end
