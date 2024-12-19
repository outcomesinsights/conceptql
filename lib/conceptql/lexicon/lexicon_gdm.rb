# frozen_string_literal: true

require_relative 'lexicon_strategy'

module ConceptQL
  class LexiconGDM < LexiconStrategy
    class << self
      def db_has_all_vocabulary_tables?(db)
        %i[ancestors concepts mappings vocabularies].all? { |t| db.table_exists?(t) }
      end
    end

    def vocabularies_query
      db[:vocabularies]
        .select(Sequel[:id].as(:id),
                Sequel[:id].as(:omopv5_vocabulary_id),
                Sequel[:vocabulary_name].as(:vocabulary_short_name),
                Sequel[:vocabulary_name].as(:vocabulary_full_name),
                Sequel[:domain],
                Sequel.expr(1).as(:from_lexicon))
    end

    def vocabularies
      vocabularies_query.all
    end

    def is_a_relationships(_data_db)
      db[:mappings].where { Sequel.function(:lower, :relationship_id) =~ 'is_a' }
    end

    def ancestors_table(_data_db)
      db[:ancestors]
    end

    def concepts_table(_data_db, some_schema = nil)
      db[:concepts]
    end

    def table_is_missing?(_data_db)
      !db.table_exists?(:concepts)
    end

    def strategy
      :gdm
    end
  end
end
