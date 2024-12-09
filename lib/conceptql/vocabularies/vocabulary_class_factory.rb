# frozen_string_literal: true

require_relative '../behaviors/drugish'
require_relative '../behaviors/labish'
require_relative 'behaviors/gdmish'
require_relative 'behaviors/omopish'
require_relative 'behaviors/sourcish'
require_relative 'behaviors/costish'
require_relative '../operators/vocabulary'

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
          gdm_wide: get_gdm_klass,
          omopv4_plus: get_omopv4_plus_klass
        }.compact
      end

      def get_gdm_klass
        get_klass do
          include Behaviors::Gdmish
        end
      end

      def get_omopv4_plus_klass
        return nil unless entry.belongs_in_omopv4_plus?

        get_klass do
          include Behaviors::Omopish

          include Behaviors::Sourcish if entry.is_source?

          include Behaviors::Costish if entry.is_costish?
        end
      end

      def get_klass(&block)
        ventry = entry
        Class.new(ConceptQL::Operators::Vocabulary) do |klass|
          @entry = ventry

          class << self
            attr_reader :entry
          end

          preferred_name entry.preferred_name
          argument :codes, type: :codelist
          aliases entry.aliases
          predominant_domains entry.predominant_domains
          short_name entry.short_name
          long_name entry.long_name
          conceptql_spec_id 'vocabulary'

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

          include ConceptQL::Behaviors::Labish if entry.is_labish?

          include ConceptQL::Behaviors::Drugish if entry.is_drugish?

          def vocab_entry
            self.class.entry
          end
        end
      end
    end
  end
end
