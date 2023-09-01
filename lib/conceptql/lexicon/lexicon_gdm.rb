require_relative "lexicon_strategy"

module ConceptQL
  class LexiconGDM < LexiconStrategy
    class << self
      def db_has_all_vocabulary_tables?(db)
        %i(ancestors concepts mappings vocabularies).all?{|t| db.table_exists?(t)}
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

    def strategy
      :gdm
    end
  end
end