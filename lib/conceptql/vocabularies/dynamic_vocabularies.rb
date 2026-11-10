# frozen_string_literal: true

require "csv"
require_relative "entry"
require_relative "drg_systems"
require_relative "read_codes"

module ConceptQL
  module Vocabularies
    class DynamicVocabularies
      # lexicons: the Lexicons whose vocabularies become operators, normally a
      # ConceptQL::Database's own and its reference lexicon (Database#operators
      # passes them). A nil one is left out. Without one, only the CSV
      # vocabularies are used.
      def initialize(*lexicons)
        @lexicons = lexicons.compact
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
      # cms_drg, which copy the entry of drg (DrgSystems). The entry of read
      # gets its preferred name (ReadCodes).
      def all_vocabs
        @all_vocabs ||= begin
          vocabs = each_vocab.each_with_object({}) do |row, h|
            entry = Entry.new(row.to_hash.compact)
            h[entry.id] ||= entry
            h[entry.id] = h[entry.id].merge(entry)
          end
          vocabs.merge(DrgSystems.entries(vocabs[DrgSystems::DRG_OPERATOR]),
                       ReadCodes.entries(vocabs[ReadCodes::OPERATOR]))
        end
      end

      private

      attr_reader :lexicons

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
      # keeps no vocabulary list contributes no vocabulary operators. A
      # vocabulary in two lexicons gets one entry (#all_vocabs merges them).
      def lexicon_vocabularies
        lexicons.flat_map { |lexicon| lexicon.respond_to?(:vocabularies) ? lexicon.vocabularies : [] }
      end
    end
  end
end
