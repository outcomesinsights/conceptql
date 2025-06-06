# frozen_string_literal: true

module ConceptQL
  module Operators
    class MultipleVocabularies < Operator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister

      class << self
        def multiple_vocabularies
          @multiple_vocabularies ||= get_multiple_vocabularies
        end

        def get_multiple_vocabularies
          [ConceptQL.multiple_vocabularies_file_path,
           ConceptQL.custom_multiple_vocabularies_file_path].select(&:exist?).map do |path|
            CSV.foreach(path, headers: true, header_converters: :symbol).each_with_object({}) do |row, h|
              (h[operator_symbol(row[:operator])] ||= []) << row.to_hash
            end
          end.inject(&:merge)
        end

        def register_many
          multiple_vocabularies.each_key do |operator_sym|
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
          op_info = multiple_vocabularies[name].first
          h[:preferred_name] = op_info[:operator]
          h[:predominant_domains] = multiple_vocabularies[name].map { |mv| mv[:domain] }.uniq.compact
          h
        end
      end

      register_many

      desc 'Selects records based on the given vocabularies.'
      argument :codes, type: :codelist
      basic_type :selection
      category 'Select by Clinical Codes'
      validate_no_upstreams
      validate_at_least_one_argument
      conceptql_spec_id 'vocabulary'

      def query(db)
        # TODO: A much-more efficient method would be to find all those vocabs
        # sharing a common table and feed them into a single single query,
        # but I think this would require some revamping of Vocabulary, and I'm
        # just not interested in taking that on right now.
        vocab_ops.map { |vo| vo.evaluate(db) }.inject do |union, q|
          union.union(q.from_self)
        end
      end

      def domains(_db)
        vocab_ops.map(&:domain).uniq
      end

      def source_table
        nil
      end

      def table
        nil
      end

      def domain
        nil
      end

      def tables
        []
      end

      def additional_validation(db, opts = {})
        vocab_ops.each { |vo| vo.valid?(db, opts) }

        @errors += aggregate_messages(vocab_ops.map(&:errors))
        @warnings += aggregate_messages(vocab_ops.map(&:warnings))
      end

      def aggregate_messages(message_sets)
        messages = message_sets.map do |message_set|
          Hash[message_set.map { |message| [message.shift, message] }]
        end

        messages_keys = messages.map(&:keys).inject(:|)

        messages = messages_keys.each.with_object({}) do |key, h|
          h[key] = messages.map { |w| w[key] || [] }.inject(:&)
        end

        messages = messages.reject { |_, v| v.empty? }

        messages.map { |k, v| [k, *v] }
      end

      def describe_codes(db, codes)
        codes = vocab_ops.flat_map do |vo|
          vo.describe_codes(db, codes)
        end

        codes_with_descriptions = codes.select(&:last)
        codes_without_descriptions = codes.reject(&:last).map(&:first)
        codes_without_descriptions -= codes_with_descriptions.map(&:first)
        codes_with_descriptions + codes_without_descriptions.zip([])
      end

      def vocab_ops
        @vocab_ops ||= self.class.multiple_vocabularies[op_name].map do |op_info|
          op_info[:vocabulary_id].to_s.downcase
        end.map do |name|
          ConceptQL::Operators.operators[dm.data_model][name].new(nodifier, name, *arguments)
        end
      end

      def preferred_name
        self.class.multiple_vocabularies[op_name].first[:operator]
      end
    end
  end
end
