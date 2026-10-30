# frozen_string_literal: true

require "csv"
require_relative "entry"
require_relative "drg_systems"

module ConceptQL
  module Vocabularies
    class DynamicVocabularies
      # lexicon: the Lexicon whose vocabularies become operators, normally a
      # ConceptQL::Database's own (Database#operators passes it). Without one,
      # only the CSV vocabularies are used.
      def initialize(lexicon = nil)
        @lexicon = lexicon
      end

      # Vocabulary operators for one data model, as name => operator class.
      # Fresh classes on every call.
      def operators(data_model)
        all_vocabs.each_with_object({}) do |(name, entry), h|
          # A CSV row marked requires_lexicon (CPT4_HCPCS) supplies metadata
          # only. Its operator exists only where the lexicon has the vocabulary.
          next if entry.requires_lexicon? && !entry.from_lexicon?

          klass = entry.dup.get_klasses[data_model]
          h[name] = klass if klass
        end
      end

      # Every vocabulary entry, as id => Entry, and the entries of ms_drg and
      # cms_drg, which copy the entry of drg (DrgSystems).
      def all_vocabs
        @all_vocabs ||= begin
          vocabs = each_vocab.each_with_object({}) do |row, h|
            entry = Entry.new(row.to_hash.compact)
            h[entry.id] ||= entry
            h[entry.id] = h[entry.id].merge(entry)
          end
          vocabs.merge(DrgSystems.entries(vocabs[DrgSystems::DRG_OPERATOR]))
        end
      end

      private

      attr_reader :lexicon

      def each_vocab
        @each_vocab ||= get_all_vocabs
      end

      def get_all_vocabs
        vocabs = [ ConceptQL.vocabularies_file_path,
                  ConceptQL.custom_vocabularies_file_path ].select(&:exist?).map do |path|
                   CSV.foreach(path, headers: true, header_converters: :symbol).to_a
                 end.inject(:+).each do |v|
          v[:from_csv] = true
        end

        lexicon_vocabularies + vocabs
      end

      # A Database accepts any object as its lexicon (opts[:lexicon]); one that
      # keeps no vocabulary list contributes no vocabulary operators.
      def lexicon_vocabularies
        lexicon.respond_to?(:vocabularies) ? lexicon.vocabularies : []
      end
    end
  end
end
