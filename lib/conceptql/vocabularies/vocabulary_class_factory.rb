require_relative "behaviors/gdmish"
require_relative "../operators/selection/vocabulary"

module ConceptQL
  module Vocabularies
    class VocabularyClassFactory
      attr_reader :entry

      def initialize(entry)
        @entry = entry
      end

      def get_klasses
        {
          gdm: get_gdm_klass,
        }.compact
      end

      def get_gdm_klass
        get_klass do
          include Behaviors::Gdmish
        end
      end

      def get_klass(&block)
        ventry = entry
        Class.new(ConceptQL::Operators::Selection::Vocabulary) do |klass|
          @entry = ventry

          def self.entry
            @entry
          end

          preferred_name entry.preferred_name
          argument :codes, type: :codelist, vocab: entry.omopv5_id
          aliases entry.aliases
          predominant_domains entry.predominant_domains
          short_name entry.short_name
          long_name entry.long_name

          klass.class_eval(&block)

          def self.inspect
            name
          end

          def self.to_s
            name
          end

          def self.name
            "ConceptQL::Operator::#{entry.id}"
          end

          if entry.is_labish?
            include ConceptQL::Behaviors::Labish
          end

          if entry.is_drugish?
            include ConceptQL::Behaviors::Drugish
          end

          def vocab_entry
            self.class.entry
          end
        end
      end
    end
  end
end

