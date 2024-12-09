# frozen_string_literal: true

require_relative 'vocabulary_class_factory'

module ConceptQL
  module Vocabularies
    class Entry
      attr_reader :hash

      METHODS = %i[
        id
        omopv4_vocabulary_id
        omopv5_vocabulary_id
        domain
        vocabulary_short_name
        vocabulary_long_name
        format_regexp
      ].freeze

      METHODS.each do |meth|
        define_method(meth) do
          hash[meth]
        end
      end

      METADATA_METHODS = METHODS + %i[
        preferred_name
        predominant_domains
      ]

      STANDARD_VOCABS = %w[
        ABMS
        AMT
        APC
        CDM
        CDT
        CMS Place of Service
        CPT4
        CVX
        Condition Type
        Cost
        Cost Type
        Currency
        DRG
        Death Type
        Device Type
        Drug Type
        Episode
        Episode Type
        Ethnicity
        GGR
        Gemscript
        Gender
        HCPCS
        HES Specialty
        HemOnc
        ICD10PCS
        ICD9Proc
        ICDO3
        JMDC
        LOINC
        MDC
        MMI
        Meas Type
        Medicare Specialty
        NAACCR
        NUCC
        Note Type
        OPCS4
        OSM
        Obs Period Type
        Observation Type
        PCORNet
        PHDSC
        PPI
        Plan
        Plan Stop Reason
        Procedure Type
        Provider
        Race
        Relationship
        Revenue Code
        RxNorm
        RxNorm Extension
        SNOMED
        SNOMED Veterinary
        Specimen Type
        Sponsor
        Supplier
        UB04 Pri Typ of Adm
        UB04 Typ bill
        UCUM
        US Census
        Visit
        Visit Type
        dm+d
      ].freeze

      COST_RELATED_VOCABS = [
        'Revenue Code',
        'DRG'
      ].freeze

      def initialize(hash)
        @hash = hash
        @hash[:omopv5_vocabulary_id] ||= @hash[:id]
        @hash[:aliases_arr] ||= []
        @hash[:aliases_arr] |= (@hash[:aliases] || '').split(';')
        @hash[:id] = @hash[:id].to_s.downcase
        @hash[:aliases_arr] << @hash[:id] if @hash[:id] =~ /\s/
        @hash[:id] = translate_id(@hash[:id].gsub(/\W+/, '_'))
        @hash[:aliases_arr] -= [@hash[:id]]
      end

      def translate_id(id)
        {
          'icd10' => 'icd10who'
        }[id] || id
      end

      def merge(other_entry)
        self.class.new(hash.merge(other_entry.hash))
      end

      def belongs_in_omopv4_plus?
        @belongs_in_omopv4_plus ||= (!from_lexicon? || from_csv?) \
          && has_domain? \
          && visible?
      end

      def is_standard?
        belongs_in_omopv4_plus? && STANDARD_VOCABS.include?(omopv5_vocabulary_id)
      end

      def is_source?
        belongs_in_omopv4_plus? && !is_standard?
      end

      def to_hash
        METADATA_METHODS.each_with_object({}) do |meth, h|
          h[meth] = send(meth)
        end
      end

      def short_name
        vocabulary_short_name || vocabulary_long_name
      end

      def long_name
        vocabulary_long_name || vocabulary_short_name
      end

      def preferred_name
        omopv5_id || id
      end

      def aliases
        @hash[:aliases_arr]
      end

      def predominant_domains
        Array(domain || :condition_occurrence).flatten
      end

      def from_lexicon?
        hash[:from_lexicon].present?
      end

      def from_csv?
        hash[:from_csv].present?
      end

      def has_domain?
        hash[:domain].present?
      end

      def hidden?
        hash[:hidden].present?
      end

      def is_labish?
        hash[:domain] =~ /observation|measurement/i
      end

      def is_drugish?
        hash[:domain] =~ /drug_exposure/i
      end

      def is_costish?
        belongs_in_omopv4_plus? && COST_RELATED_VOCABS.include?(omopv5_vocabulary_id)
      end

      def visible?
        !hidden?
      end

      def omopv5_id
        omopv5_vocabulary_id || id
      end

      def omopv4_id
        omopv4_vocabulary_id
      end

      def get_klasses
        VocabularyClassFactory.new(self).get_klasses
      end
    end
  end
end
