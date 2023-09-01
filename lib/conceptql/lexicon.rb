require "forwardable"
require_relative "lexicon/lexicon_gdm"
require_relative "lexicon/lexicon_ohdsi"

module ConceptQL
  class Lexicon
    extend Forwardable
    attr_reader :strategy
    def_delegators :@strategy,
      :strategy,
      :vocabularies,
      :vocabularies_query

    @@db_lock = Mutex.new

    def initialize(lexicon_db, dataset_db = nil)
      lexicon_classes.each do |klass|
        [dataset_db, lexicon_db].compact.each do |db|
          if (klass.db_has_all_vocabulary_tables?(db))
            @strategy = klass.new(db, @@db_lock)
            break
          end
        end
        break if @strategy
      end
      raise "Could not find vocabulary tables for GDM or OHDSI in SEQUELIZER_URL: #{ENV['SEQUELIZER_URL']} or LEXICON_URL: #{ENV['LEXICON_URL']}" unless @strategy
    end

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV["LEXICON_GDM_ONLY"]
      classes << LexiconGDM unless ENV["LEXICON_OHDSI_ONLY"]
      classes
    end
  end
end
