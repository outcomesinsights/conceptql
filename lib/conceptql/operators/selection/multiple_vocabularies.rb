require_relative "base"

module ConceptQL
  module Operators
  module Selection
    class MultipleVocabularies < Base
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister
      include ConceptQL::Behaviors::Unionable

      class << self
        def multiple_vocabularies
          @multiple_vocabularies ||= get_multiple_vocabularies
        end

        def get_multiple_vocabularies
          [ConceptQL.multiple_vocabularies_file_path, ConceptQL.custom_multiple_vocabularies_file_path].select(&:exist?).map do |path|
            CSV.foreach(path, headers: true, header_converters: :symbol).each_with_object({}) do |row, h|
              (h[operator_symbol(row[:operator])] ||= []) << row.to_hash
            end
          end.inject(&:merge)
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
          op_info = multiple_vocabularies[name].first
          h[:preferred_name] = op_info[:operator]
          h[:predominant_domains] = multiple_vocabularies[name].map { |mv| mv[:domain] }.uniq.compact
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

      def domains(db)
        vocab_ops.map(&:domain).uniq
      end

      def source_table
        domains(nil)
      end

      def table
        dm.nschema.cc_cql
      end

      def domain
        domains(nil)
      end

      def vocabulary_id
        vocab_ops.map(&:vocabulary_id)
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
          nodifier.create(name, *arguments).tap { |op| op.required_columns = required_columns_for_upstream }
        end
      end

      def preferred_name
        self.class.multiple_vocabularies[op_name].first[:operator]
      end
    end
  end
end
end
