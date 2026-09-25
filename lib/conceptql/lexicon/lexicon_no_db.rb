# frozen_string_literal: true

require_relative 'lexicon_strategy'

module ConceptQL
  # The strategy used when neither the dataset db nor the lexicon db has
  # vocabulary tables (for instance a db-less ConceptQL::Database, as the
  # diagram renderer uses). Its db is a Sequel mock, so every lookup returns
  # no rows, but SQL that joins or selects from the vocabulary tables can
  # still be BUILT.
  #
  # It must answer the same table methods as the other strategies, because
  # LexiconStrategy's lookups (concepts, descendants_of,
  # related_concept_ids, ...) are written against them. The tables are named
  # in the GDM layout (concepts / ancestors / mappings), matching
  # #vocabularies_query, which already reads GDM's `vocabularies` table, and
  # the columns that LexiconStrategy's queries use (id, concept_code,
  # vocabulary_id, concept_text; ancestor_id / descendant_id;
  # concept_1_id / concept_2_id).
  class LexiconNoDB < LexiconStrategy
    def vocabularies_query
      db[:vocabularies]
    end

    def vocabularies
      []
    end

    def is_a_relationships(_data_db)
      db[:mappings].where { Sequel.function(:lower, :relationship_id) =~ 'is_a' }
    end

    def ancestors_table(_data_db)
      db[:ancestors]
    end

    def concepts_table(_data_db, _some_schema = nil)
      db[:concepts]
    end

    def table_is_missing?(_db)
      true
    end

    def strategy
      :no_db
    end
  end
end
