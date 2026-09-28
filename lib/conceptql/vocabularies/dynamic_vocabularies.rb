# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'csv'
require_relative 'entry'

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
          klass = entry.dup.get_klasses[data_model]
          h[name] = klass if klass
        end
      end

      def all_vocabs
        @all_vocabs ||= each_vocab.each_with_object({}) do |row, h|
          entry = Entry.new(row.to_hash.compact)
          h[entry.id] ||= entry
          h[entry.id] = h[entry.id].merge(entry)
        end
      end

      private

      attr_reader :lexicon

      def each_vocab
        @each_vocab ||= get_all_vocabs
      end

      def get_all_vocabs
        vocabs = [ConceptQL.vocabularies_file_path,
                  ConceptQL.custom_vocabularies_file_path].select(&:exist?).map do |path|
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
