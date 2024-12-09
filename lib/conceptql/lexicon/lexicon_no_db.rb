# frozen_string_literal: true

require_relative 'lexicon_strategy'

module ConceptQL
  class LexiconNoDB < LexiconStrategy
    def vocabularies_query
      db[:vocabularies]
    end

    def vocabularies
      []
    end

    def strategy
      :no_db
    end
  end
end
