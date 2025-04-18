# frozen_string_literal: true

require 'forwardable'
require_relative 'lexicon/lexicon_gdm'
require_relative 'lexicon/lexicon_no_db'
require_relative 'lexicon/lexicon_ohdsi'

module ConceptQL
  class Lexicon
    extend Forwardable
    attr_reader :strategy

    def_delegators :@strategy,
                   :strategy,
                   :concept_ids,
                   :concepts,
                   :concepts_table,
                   :concepts_by_name,
                   :concepts_ds,
                   :concepts_to_codes,
                   :descendants_of,
                   :known_codes,
                   :related_concept_ids,
                   :vocabularies,
                   :vocabularies_query

    def initialize(lexicon_db, dataset_db = nil, strategy: nil)
      @strategy = strategy || determine_strategy(lexicon_db, dataset_db)
    end

    def determine_strategy(lexicon_db, dataset_db)
      [dataset_db, lexicon_db].compact.each do |db|
        lexicon_classes.each do |klass|
          next unless klass.db_has_all_vocabulary_tables?(db)

          return(klass.new(db))
        end
      end
      LexiconNoDB.new(Sequel.mock(host: :postgres))
    end

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV['LEXICON_GDM_ONLY']
      classes << LexiconGDM unless ENV['LEXICON_OHDSI_ONLY']
      classes
    end
  end
end
