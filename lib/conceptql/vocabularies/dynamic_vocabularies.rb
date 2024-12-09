# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'csv'
require 'sequelizer'
require_relative 'entry'
require_relative '../database'

module ConceptQL
  module Vocabularies
  end
end

module ConceptQL
  module Vocabularies
    class DynamicVocabularies
      include Sequelizer

      def register_operators
        all_vocabs.each do |name, entry|
          entry.dup.get_klasses.each do |data_model, klass|
            klass.register(name, data_model)
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

      def lexicon_vocabularies
        lexicon ? lexicon.vocabularies : []
      end

      def lexicon
        @lexicon || ConceptQL::Database.lexicon(db)
      end
    end
  end
end
