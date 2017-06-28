require_relative "operator"
require_relative "vocabulary"

module ConceptQL
  module Operators
    class MultipleVocabularies < Operator
      class << self
        def multiple_vocabularies
          @multiple_vocabularies ||= CSV.foreach(multiple_vocabulary_file, headers: true, header_converters: :symbol).each_with_object({}) { |row, h| (h[operator_symbol(row[:operator])] ||= []) << row.to_hash }
        end

        def multiple_vocabulary_file
          ConceptQL.config_dir + "multiple_vocabularies.csv"
        end

        def register_many
          multiple_vocabularies.keys.each do |operator_sym|
            register(operator_sym)
          end
        end

        def operator_symbol(word)
          word.gsub(/\W+/, '_').downcase
        end

        # This will override the to_metadata method and return the preferred name
        # based on the name listed in the file.
        #
        # This method will be called once for each vocabulary we register
        # for this operator
        def to_metadata(name, opts = {})
          h = super
          op_info = multiple_vocabularies[name]
          h[:preferred_name] = op_info[:operator]
          h
        end
      end

      register_many

      desc 'Returns all records that match the given codes for the given vocabulary'
      argument :codes, type: :codelist
      basic_type :selection
      category "Select by Clinical Codes"
      validate_no_upstreams
      validate_at_least_one_argument

      def query(db)
        # TODO: A much-more efficient method would be to find all those vocabs
        # sharing a common table and feed them into a single single query,
        # but I think this would require some revamping of Vocabulary, and I'm
        # just not interested in taking that on right now.
        vocab_ops.map { |vo| vo.evaluate(db) }.inject do |union, q|
          union.union(q)
        end
      end

      def validate(db, opts = {})
        super
        vocab_ops.each { |vo| vo.validate(db, opts) }
      end

      def describe_codes(db, codes)
        vocab_ops.map { |vo| vo.describe_codes(db, opts) }.inject(&:+)
      end

      def vocab_ops
        @vocab_ops ||= self.class.multiple_vocabularies[op_name].map { |op_info| op_info[:vocabulary_id] }.map { |vocab_id| Vocabulary.new(nodifier, vocab_id, *arguments) }
      end
    end
  end
end
