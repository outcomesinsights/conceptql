require "sequelizer"
require_relative "operator"
require "csv"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      extend Sequelizer
      include ConceptQL::Behaviors::Windowable

      class << self
        def v4_vocab_to_v5_vocab
          each_vocab.each_with_object({}) do |row, h|
            h[row[:omopv4_vocabulary_id]] = row[:id]
          end
        end

        def v5_vocab_to_v4_vocab
          each_vocab.each_with_object({}) do |row, h|
            h[row[:id]] = row[:omopv4_vocabulary_id]
          end
        end

        def assigned_vocabularies
          each_vocab.each_with_object({}) do |row, h|
            h[row[:id]] = row.to_hash
          end.select { |k, vocab| vocab[:hidden].nil? }
        end

        def register_many
          assigned_vocabularies.each do |name, vocab|
            register(name)
          end
        end

        def each_vocab
          CSV.foreach(vocabs_file, headers: true, header_converters: :symbol)
        end

        def vocabs_file
          ConceptQL.config_dir + "vocabularies.csv"
        end

        def from_old_vocab(nodifier, old_vocab_id, *values)
          new(nodifier, v4_vocab_to_v5_vocab[old_vocab_id.to_s], *values)
        end

        # This will override the to_metadata method and return the preferred name
        # based on the name listed in the file.
        #
        # This method will be called once for each vocabulary we register
        # for this operator
        def to_metadata(name, opts = {})
          h = super
          vocab = assigned_vocabularies[name]
          h[:preferred_name] = vocab[:vocabulary_short_name] || vocab[:id]
          h
        end
      end

      register_many

      desc 'Returns all records that match the given codes for the given vocabulary'
      argument :codes, type: :codelist
      basic_type :selection
      query_columns :clinical_codes
      category "Select by Clinical Codes"
      validate_no_upstreams
      validate_at_least_one_argument

      def query(db)
        ds = db[dm.table_by_domain(:condition_occurrence)]

        ds = ds.where(where_clause(db))
        if gdm?
          ds = ds.select_append(Sequel.cast_string(domain.to_s).as(:criterion_domain))
        end
        ds
      end

      def where_clause(db)
        if gdm?
          concept_ids = db[:concepts].where(vocabulary_id: vocabulary_id(db), concept_code: values.flatten).select(:id)
          { clinical_code_concept_id: concept_ids }
        else
          {
            condition_source_vocabulary_id: vocabulary_id(db),
            condition_source_value: values
          }
        end
      end

      def domain
        domain_map(op_name)
      end

      def table
        :clinical_codes
      end

      def query_cols
        if gdm?
          dm.table_columns(:clinical_codes)
        else
          dm.table_columns(domain)
        end
      end

      def validate(db, opts = {})
        super
        if add_warnings?(db, opts)
          args = arguments.dup
          args -= bad_arguments
          missing_args = []

          unless no_db?(db, opts)
            missing_args = args - db[:concepts].where(vocabulary_id: vocabulary_id(db), concept_code: args).select_map(:concept_code) rescue []
          end

          unless missing_args.empty?
            add_warning("unknown source code", *missing_args)
          end
        end
      end

      def describe_codes(db, codes)
        db[:concepts].where(vocabulary_id: vocabulary_id(db), concept_code: codes).select_map([:concept_code, :concept_text])
      end

      private

      def vocabulary_id(db)
        @vocabulary_id ||= translated_vocabulary_id(db)
      end

      def translated_vocabulary_id(db)
        return op_name if gdm?
        return translate_to_old(op_name)
      end

      def translate_to_old(v_id)
        self.class.v5_vocab_to_v4_vocab[v_id.to_s]
      end

      def domain_map(v_id)
        case v_id
        when 'ICD9CM', 'ICD10CM', 'SNOMED', 2, 70, 1
          :condition_occurrence
        when 'CPT', 'HCPCS', 'ICD10PCS', 'ICD9Proc', 4, 5, 35, 3
          :procedure_occurrence
        when 'NDC', 'RxNorm', 8, 9
          :drug_exposure
        when 'LOINC', 6
          :observation
        when Array
          domain_map(v_id.first)
        else
          :condition_occurrence
        end
      end
    end
  end
end

