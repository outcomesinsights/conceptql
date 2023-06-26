require "forwardable"
require_relative "lexicon/lexicon_gdm"

module ConceptQL
  class Lexicon
    extend Forwardable
    attr_reader :strategy
    def_delegators :@strategy, :descendants_of, :codes_by_domain, :known_codes, :concepts, :vocabularies, :concept_ids, :vocabularies_query

    @@db_lock = Mutex.new

    def initialize(lexicon_db, dataset_db = nil)
      [LexiconGDM].each do |klass|
        [dataset_db, lexicon_db].compact.each do |db|
          if (klass.db_has_all_vocabulary_tables?(db))
            @strategy = klass.new(db, @@db_lock)
            break
          end
        end
        break if @strategy
      end
    end
  end
end
