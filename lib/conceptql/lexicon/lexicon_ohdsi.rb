# frozen_string_literal: true

require_relative 'lexicon_strategy'

module ConceptQL
  class LexiconOhdsi < LexiconStrategy
    class << self
      def db_has_all_vocabulary_tables?(db)
        %i[concept_ancestor concept concept_relationship vocabulary].all? { |t| db.table_exists?(t) }
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
        .where { Sequel.function(:lower, :relationship_id) =~ 'is a' }
        .from_self
    end

    def ancestors_table(_data_db)
      db[:concept_ancestor].select(
        Sequel[:ancestor_concept_id].as(:ancestor_id),
        Sequel[:descendant_concept_id].as(:descendant_id)
      ).from_self
    end

    def concepts_table(_data_db, some_schema = nil)
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

    def strategy
      :ohdsi
    end
  end
end
