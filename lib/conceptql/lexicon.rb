require "forwardable"
require_relative "lexicon/lexicon_gdm"
require_relative "lexicon/lexicon_ohdsi"

module ConceptQL
  class Lexicon
    extend Forwardable
    attr_reader :strategy
    def_delegators :@strategy,
      :code_provenance_types_vocab,
      :codes_by_domain,
      :concept_ids,
      :concepts,
      :concepts_to_codes,
      :descendants_of,
      :file_provenance_types_vocab,
      :known_codes,
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
    end

    def lexicon_classes
      classes = []
      classes << LexiconOhdsi unless ENV["CONCEPTQL_LEXICON_GDM_ONLY"]
      classes << LexiconGDM unless ENV["CONCEPTQL_LEXICON_OHDSI_ONLY"]
      classes
    end
  end
end
