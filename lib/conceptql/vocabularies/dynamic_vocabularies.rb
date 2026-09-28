# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'csv'
require 'sequelizer'
require_relative 'entry'
require_relative '../database'

module ConceptQL
  module Vocabularies
    class DynamicVocabularies
      include Sequelizer

      # lexicon: the Lexicon whose vocabularies become operators, normally a
      # ConceptQL::Database's own (Database#operators passes it). Without one,
      # the vocabularies come from ConceptQL::Database.lexicon, which connects
      # to whatever Sequelizer is configured for.
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

      # Writes into the global registry only. Operator.register would also put
      # these classes in Operators.static_operators, which holds built-ins.
      def register_operators
        all_vocabs.each do |name, entry|
          entry.dup.get_klasses.each do |data_model, klass|
            ConceptQL::Operators.operators[data_model][name] = klass
          end
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

      def lexicon
        @lexicon || ConceptQL::Database.lexicon(db)
      end
    end
  end
end
