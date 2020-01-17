require_relative "vocabulary_class_factory"

module ConceptQL
  module Vocabularies
    class Entry
      attr :hash

      METHODS = %i(
        id
        omopv4_vocabulary_id
        omopv5_vocabulary_id
        domain
        vocabulary_short_name
        vocabulary_long_name
        format_regexp
      )

      METHODS.each do |meth|
        define_method(meth) do
          hash[meth]
        end
      end

      METADATA_METHODS = METHODS + %i(
        preferred_name
        predominant_domains
      )

      def initialize(hash)
        @hash = hash
        @hash[:omopv5_vocabulary_id] ||= @hash[:id]
        @hash[:aliases_arr] ||= []
        @hash[:aliases_arr] |= (@hash[:aliases] || "").split(";")
        @hash[:id] = @hash[:id].to_s.downcase
        @hash[:aliases_arr] << @hash[:id] if @hash[:id] =~ /\s/
        @hash[:id] = translate_id(@hash[:id].gsub(/\W+/, "_"))
        @hash[:aliases_arr] -= [@hash[:id]]
      end

      def translate_id(id)
        {
          "icd10" => "icd10who"
        }[id] || id
      end

      def merge(other_entry)
        self.class.new(hash.merge(other_entry.hash))
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
        hash[:domain] =~ /observation|measurement/i || %w[Read].include?(omopv5_id)
      end

      def is_drugish?
        hash[:domain] =~ /drug_exposure/i
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

