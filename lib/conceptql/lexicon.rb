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
                   :vocabularies,
                   :vocabularies_query

    def initialize(lexicon_db, dataset_db = nil)
      lexicon_classes.each do |klass|
        [dataset_db, lexicon_db].compact.each do |db|
          if klass.db_has_all_vocabulary_tables?(db)
            @strategy = klass.new(db)
            break
          end
        end
        break if @strategy
      end
      @strategy ||= LexiconNoDB.new(Sequel.mock(host: :postgres))
    end

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV['LEXICON_GDM_ONLY']
      classes << LexiconGDM unless ENV['LEXICON_OHDSI_ONLY']
      classes
    end
  end
end
