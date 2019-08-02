require "active_support/core_ext/object/blank"

module ConceptQL
  class DynamicVocabularies
    def register_operators

    end

    private

    def all_vocabs
      @all_vocabs ||= each_vocab.each_with_object({}) do |row, h|
        entry = Entry.new(row.to_hash.compact)
        h[entry.id] ||= entry
        h[entry.id] = h[entry.id].merge(entry)
      end
    end

    def each_vocab
      @each_vocab ||= get_all_vocabs
    end

    def get_all_vocabs
      vocabs = [ConceptQL.vocabularies_file_path, ConceptQL.custom_vocabularies_file_path].select(&:exist?).map do |path|
        CSV.foreach(path, headers: true, header_converters: :symbol).to_a
      end.inject(:+).each { |v| v[:from_csv] = true }

      lexicon_vocabularies + vocabs
    end

    def lexicon_vocabularies
      lexicon ? lexicon.vocabularies : []
    end

    def lexicon
      @lexicon || ConceptQL::Database.lexicon
    end
  end
end
