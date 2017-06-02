require "sequelizer"
require_relative "operator"
require "csv"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      extend Sequelizer
      register __FILE__

      class << self
        def setup_vocabulary_operator
          return unless vocabs_file.exist?
          category "Select by Clinical Codes"
          vocabularies.values.sort_by(&:downcase)
        end

        def vocabularies
          CSV.foreach(vocabs_file, headers: true, header_converters: :symbol).each_with_object({}) do |row, h|
            h[row[:omopv4_vocabulary_id]] = row[:id]
          end
        end

        def vocabs_file
          ConceptQL.config_dir + "vocabularies.csv"
        end

        def get_vocabularies
          vocabs = db[:concepts].select_group(:vocabulary_id).select_order_map(:vocabulary_id)
          vocabs
        rescue
          puts $!.message
          puts $!.backtrace.join("\n")
          puts "Failed to load voabularies for Vocabulary Operator"
        end
      end

      desc 'Returns all records that match the given codes for the given vocabulary'
      option :vocabulary, type: :string, options: setup_vocabulary_operator, required: true
      argument :codes, type: :codelist
      basic_type :selection
      query_columns :clinical_codes
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
        domain_map(options[:vocabulary])
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
        v_id = options[:vocabulary]
        if gdm?
          return v_id if v_id.is_a?(String)
          return translate_to_new(db, v_id)
        else
          return v_id unless v_id.is_a?(String)
          return translate_to_old(db, v_id)
        end
      end

      def translate_to_new(db, v_id)
        self.class.vocabularies[v_id.to_s]
      end

      def translate_to_old(db, v_id)
        db[:vocabularies].where(id: v_id).select_map(:omopv4_vocabulary_id).first
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

