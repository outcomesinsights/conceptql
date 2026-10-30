# frozen_string_literal: true

module ConceptQL
  class LexiconStrategy
    attr_reader :db

    def initialize(db)
      @db = db
    end

    # A lookup is always scoped to a vocabulary. `vocabulary_id` is a String or
    # an Array of vocabulary names (the provenance-type pairs), which Sequel turns
    # into an IN clause.
    #
    # There is deliberately no wildcard. `'*'` is meaningful elsewhere in the
    # operator family, but only in `arguments` — Vocabulary#select_all? reads it
    # there and *skips* the lexicon call entirely. An earlier version of this
    # method honoured `'*'` here too, which no caller ever used and which read as
    # support for cross-vocabulary lookup that does not exist.
    def concepts(data_db, vocabulary_id, codes = [])
      if vocabulary_id.blank? || Array(vocabulary_id).include?("*")
        raise ArgumentError,
              "concepts requires a specific vocabulary, got #{vocabulary_id.inspect}. " \
              "There is no wildcard lookup; pass a vocabulary name, an Array of them, " \
              "or an id. ('*' belongs in arguments, where Vocabulary#select_all? handles it.)"
      end

      ds = concepts_table(data_db)

      ds = ds.where(vocabulary_id: vocabulary_id)
      ds = ds.where(Sequel.function(:lower, :concept_code) => Array(codes).map(&:downcase)) unless codes.blank?

      ds
    end

    def concepts_by_name(data_db, names = [])
      ds = concepts_table(data_db)

      ds.where(Sequel.function(:lower, :concept_text) => Array(names).map(&:downcase))
    end

    def descendants_of(_data_db, concept_ids_or_ds)
      where_values = Array(concept_ids_or_ds).flatten.dup

      descendants = ancestors_table(db)
                    .where(ancestor_id: where_values)
                    .select(:descendant_id)

      unless where_values.empty?
        union_clause = db.values(where_values.map { |v| [ v ] })
        descendants = descendants.union(union_clause).distinct
      end

      descendants.select_map(:descendant_id)
    end

    def concept_ids(_data_db, vocabulary_id, codes = [])
      concepts(db, vocabulary_id, codes)
        .select_map(:id)
    end

    # Every concept code in the vocabulary (or vocabularies).
    def concept_codes(data_db, vocabulary_id)
      concepts(data_db, vocabulary_id).select_map(:concept_code)
    end

    def concept_ids_by_name(data_db, names)
      concepts_by_name(data_db, names).select_map(:id)
    end

    # The mappings table will tell us what other concepts have been directly
    # mapped to the concepts passed in
    def related_concept_ids(data_db, *ids)
      ids = ids.flatten
      other_ids = is_a_relationships(data_db)
                  .where(concept_2_id: ids)
                  .select_map(:concept_1_id)
      other_ids + ids
    end

    # A caller can answer "is the vocabulary empty?" with a block. The
    # Lexicon does, so that the answer comes from its cache.
    def known_codes(data_db, vocabulary_id, codes)
      return codes if db_is_mock?(data_db)
      return codes if block_given? ? yield : vocabulary_is_empty?(data_db, vocabulary_id)

      concepts_ds(data_db, vocabulary_id, codes).select_map(:concept_code)
    rescue Sequel::DatabaseError
      []
    end

    # A caller can answer "is the concept table missing?" with a block. The
    # Lexicon does, so that the answer comes from its cache.
    def concepts_to_codes(data_db, vocabulary_id, codes = [])
      missing = db.nil? || (block_given? ? yield : table_is_missing?(data_db))
      return codes.map { |code| [ code, nil ] } if missing

      concepts(db, vocabulary_id, codes).select_map(%i[concept_code concept_text])
    end

    # The distinct names of each code that has more than one name, as
    # { downcased code => [name, ...] } with the names sorted. A vocabulary
    # can reuse a code for a new meaning: DRG 410 meant chemotherapy until
    # 2007-09-30 and a biliary tract procedure after that. OHDSI keeps each
    # meaning as its own concept row, and the GDM vocabulary keeps both names.
    # Names that differ only in case or spacing count as one name.
    # A caller can answer "is the concept table missing?" with a block.
    def code_meanings(data_db, vocabulary_id, codes)
      return {} if codes.blank? || db.nil? || db_is_mock?(data_db)
      return {} if block_given? ? yield : table_is_missing?(data_db)

      concepts(db, vocabulary_id, codes)
        .select_map(%i[concept_code concept_text])
        .group_by { |code, _| code.downcase }
        .transform_values { |rows| rows.map(&:last).compact.uniq { |name| name.downcase.split.join(" ") }.sort }
        .select { |_, names| names.length > 1 }
    rescue Sequel::DatabaseError
      {}
    end

    def vocabulary_is_empty?(data_db, vocabulary_id)
      concepts_table(data_db).where(vocabulary_id: vocabulary_id).count.zero?
    end

    def concepts_ds(data_db, vocabulary_id, codes)
      concepts_table(data_db)
        .where(vocabulary_id: vocabulary_id, concept_code: codes)
        .select(Sequel[:concept_code].as(:concept_code), Sequel[:concept_text].as(:concept_text))
        .from_self
    end

    def db_is_mock?(_data_db)
      db.is_a?(Sequel::Mock::Database)
    end
  end
end
