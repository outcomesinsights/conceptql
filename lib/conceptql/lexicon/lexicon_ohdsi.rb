# frozen_string_literal: true

require_relative "lexicon_strategy"

module ConceptQL
  class LexiconOhdsi < LexiconStrategy
    # The OHDSI vocabulary tables. A db that has all four can be the lexicon.
    VOCABULARY_TABLES = %i[concept concept_ancestor concept_relationship vocabulary].freeze

    class << self
      def db_has_all_vocabulary_tables?(db)
        VOCABULARY_TABLES.all? { |t| db.table_exists?(t) }
      end
    end

    def vocabularies_query
      db[:vocabulary]
        .select(Sequel[:vocabulary_id].as(:id),
                Sequel[:vocabulary_id].as(:omopv5_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel[nil].as(:domain),
                Sequel.expr(1).as(:from_lexicon))
        .from_self
    end

    def vocabularies
      vocabularies_query.all
    end

    def is_a_relationships(_data_db)
      db[:concept_relationship]
        .select(
          Sequel[:concept_id_1].as(:concept_1_id),
          Sequel[:concept_id_2].as(:concept_2_id),
          :relationship_id
        )
        .where { Sequel.function(:lower, :relationship_id) =~ "is a" }
        .from_self
    end

    def ancestors_table(_data_db)
      db[:concept_ancestor].select(
        Sequel[:ancestor_concept_id].as(:ancestor_id),
        Sequel[:descendant_concept_id].as(:descendant_id)
      ).from_self
    end

    def concepts_table(_data_db, _some_schema = nil)
      db[:concept].select(
        Sequel[:concept_id].as(:id),
        :concept_code,
        :vocabulary_id,
        Sequel[:concept_name].as(:concept_text)
      ).from_self
    end

    def table_is_missing?(_data_db)
      !db.table_exists?(:concept)
    end

    # A caller can answer "is the concept table missing?" with a block. A
    # concept table without concept_class_id answers nil, as a lexicon
    # without classes does.
    def concepts_to_codes_in_class(data_db, vocabulary_id, concept_class_id, codes)
      return nil if codes.blank? || db_is_mock?(data_db)
      return nil if block_given? ? yield : table_is_missing?(data_db)

      db[:concept]
        .where(vocabulary_id: vocabulary_id, concept_class_id: concept_class_id)
        .where(code_condition(vocabulary_id, codes))
        .select_map(%i[concept_code concept_name])
    rescue Sequel::DatabaseError
      nil
    end

    def strategy
      :ohdsi
    end
  end
end
