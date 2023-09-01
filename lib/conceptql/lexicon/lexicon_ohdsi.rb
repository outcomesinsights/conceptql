require_relative "lexicon_strategy"

module ConceptQL
  class LexiconOhdsi < LexiconStrategy
    class << self
      def db_has_all_vocabulary_tables?(db)
        %i(concept_ancestor concept concept_relationship vocabulary).all?{|t| db.table_exists?(t)}
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

    def strategy
      :ohdsi
    end
  end
end