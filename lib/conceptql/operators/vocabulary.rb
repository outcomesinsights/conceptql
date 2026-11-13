# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      # The vocabulary operators share one reference section (spec_id
      # vocabulary-operator): each generated vocabulary operator (read is
      # one) and the multiple vocabulary operators. So the section's texts
      # are written on this class: `returns`, the meaning: of the codes
      # argument, and each `example`. An operator of the section extends this
      # module and serves the returns text, and only the examples whose
      # statement starts with its own name, so no operator shows an example
      # of another one.
      module SharedDocumentation
        def get_returns
          super || Vocabulary.returns
        end

        def examples_for(name)
          Vocabulary.examples.select { |example| example[:statement].first.to_s == name }
        end
      end

      extend SharedDocumentation

      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister

      category "Select by Clinical Codes"
      basic_type :selection
      effects :select
      desc "Selects the records whose code is one of the given codes in a vocabulary, such as ICD-9-CM diagnoses or CPT procedures. " \
           "Each vocabulary has its own operator, and a few operators search several vocabularies at once."
      validate_no_upstreams
      validate_at_least_one_argument
      validate_codes_match

      # VocabularyClassFactory gives each vocabulary operator a copy of this
      # argument, with the label "<preferred name> Codes"
      argument :codes, type: :codelist,
                       meaning: "One or more codes of the vocabulary. Write each code as the vocabulary writes it, " \
                                "including any dots: 250.01, not 25001. A code matches exactly, including case, " \
                                "and it does not select its child codes. A code alone of * selects every record " \
                                "of the vocabulary, and there is no other wildcard. A code that does not have the " \
                                "vocabulary's format matches nothing and gives a warning."

      returns "Every record whose code is one of the given codes in the operator's vocabulary. " \
              "The type of the records depends on the vocabulary, for example condition_occurrence for icd9cm " \
              "and procedure_occurrence for cpt4. An operator does not follow mappings to other vocabularies."
      example "All records with the ICD-9-CM diagnosis code 412 (old myocardial infarction)", [ "icd9cm", "412" ]
      example "All MS-DRG 205 records: other respiratory system diagnoses with a major complication or comorbidity",
              [ "ms_drg", "205" ]
      # The test data has no DRG record before 2007-10-01
      example "All CMS-DRG 205 records (a liver disorder)", [ "cms_drg", "205" ], help: false

      def source_table
        domain_map(op_name)
      end

      def table
        domain_map(op_name)
      end

      def domain
        domain_map(op_name)
      end

      def domains(_db)
        vocab_entry.predominant_domains.map(&:to_sym)
      end

      # Production ETL data stores CPT-4 and HCPCS codes only under the merged
      # vocabulary CPT4_HCPCS. cpt and hcpcs read only their own vocabulary,
      # so they select no rows there (known issue conceptql-rpy3). Each key is
      # a vocabulary whose codes can be stored under the merged vocabulary,
      # and each value names that vocabulary and the operator that reads it.
      MERGED_VOCABULARIES = {
        "CPT4" => { vocabulary_id: "CPT4_HCPCS", operator: "cpt_or_hcpcs" },
        "HCPCS" => { vocabulary_id: "CPT4_HCPCS", operator: "cpt_or_hcpcs" }
      }.freeze
      NO_RECORDS_IN_DATA = "the data has no records of this vocabulary"
      NOT_PRESENT_IN_DATASET = "code(s) not present in this dataset"

      # MultipleVocabularies passes skip_merged_vocabulary_check to its
      # vocabulary operators. It reads the merged vocabulary itself, and it
      # would drop these warnings anyway (see #warn_about_merged_vocabulary).
      # The merged-vocabulary and the no-records checks read the data, so
      # they need a data database. The code checks read only the lexicon.
      # When the merged-vocabulary warning fires, it names the operator to
      # use, so the no-records check does not add a second warning with the
      # same text.
      #
      # Database#check_codes sorts the codes that the Database's lexicon does
      # not know into "code(s) not present in this dataset" and "unknown
      # code(s)", and applies the 2020 rule. Each warning lists every code.
      # When the data has no records of the vocabulary at all, the no-records
      # warning already says that every code is absent, so the not-present
      # warning is not given. The unknown-code and reused-code warnings still
      # are, so a typo is not hidden (bead conceptql-dufi).
      def additional_validation(db, opts = {})
        if add_warnings?(db, opts) && !opts[:skip_merged_vocabulary_check]
          merged_warning = warn_about_merged_vocabulary(db)
          check_for_records(db, warn: !merged_warning)
        end
        return unless lexicon_checks?(opts)
        return if select_all?

        args = arguments - bad_arguments
        not_present, unknown = nodifier.cdb.check_codes(db, vocabulary_id, args)
        add_warning(NOT_PRESENT_IN_DATASET, *not_present) unless not_present.empty? || @no_records_in_data
        add_warning(UNKNOWN_CODE, *unknown) unless unknown.empty?

        warn_about_reused_codes(db, args - not_present - unknown)
      end

      # Warns when the data has no record of this vocabulary but has records
      # of the merged vocabulary that holds its codes, and the Database's
      # lexicon carries that merged vocabulary (bead conceptql-k5ho). The
      # warning names the operator to use instead. The test fixture keeps
      # CPT4 and HCPCS rows, so it never shows this warning. It returns the
      # warnings when it adds one, and nil otherwise.
      def warn_about_merged_vocabulary(db)
        merged = MERGED_VOCABULARIES[vocabulary_id]
        return unless merged && nodifier.operators.key?(merged[:vocabulary_id].downcase)

        table = db[criterion_table]
        return unless table.where(vocabulary_condition).empty?
        return if table.where(vocabulary_condition.transform_values { merged[:vocabulary_id] }).empty?

        add_warning(NO_RECORDS_IN_DATA,
                    "the data stores #{vocabulary_id} codes as #{merged[:vocabulary_id]}, so use #{merged[:operator]}")
      end

      # Warns when etl_vocabulary_ids lists the vocabularies of the data's
      # clinical codes and this vocabulary is not among them (bead
      # conceptql-d1bd). A count of 0 would then say that no patient has the
      # codes, which the data cannot show, so #annotate reports null counts.
      # With warn: false (the merged-vocabulary warning fired, with the same
      # text), the counts are null and no second warning is added.
      # etl_vocabulary_ids covers the clinical codes only, so an operator
      # that reads another table (death type, observation period type) is
      # not checked. Neither is a dataset without the table.
      def check_for_records(db, warn: true)
        return unless absent_from_data?(db)

        @no_records_in_data = true
        add_warning(NO_RECORDS_IN_DATA) if warn
      end

      # Whether etl_vocabulary_ids lists the vocabularies of the data's
      # clinical codes and this vocabulary is not among them. See
      # #check_for_records. MultipleVocabularies asks each of its vocabulary
      # operators.
      def absent_from_data?(db)
        return false unless criterion_table == dm.table_by_domain(:clinical_codes)
        return false unless (ids = nodifier.etl_vocabulary_ids(db))

        !ids.include?(vocabulary_id)
      end

      # Whether the data has no records of this vocabulary at all, as
      # #check_for_records found.
      def no_records_in_data?(db, opts = {})
        validate(db, opts)
        @no_records_in_data || false
      end

      # A code that the vocabulary reused for a new meaning selects records of
      # both meanings: DRG 410 selects chemotherapy stays before 2007-10-01 and
      # biliary tract procedures after it (conceptql-ttk). Each item names the
      # code and all of its names, so the user sees the problem without a
      # vocabulary lookup.
      def warn_about_reused_codes(db, codes)
        meanings = dm.code_meanings(db, vocabulary_id, codes, check_case: false)
        reused = codes.filter_map do |code|
          names = meanings[code]
          "#{code}: #{names.join(' | ')}" if names
        end
        add_warning("code(s) with more than one meaning", *reused) unless reused.empty?
      end

      def describe_codes(db, codes)
        return [ [ "*", "ALL CODES" ] ] if select_all?

        found_codes = dm.concepts_to_codes(db, vocabulary_id, codes, check_case: false)

        found_codes + (codes - found_codes.map(&:first)).zip([])
      end

      def filter_clause(db)
        filter_clause = Sequel[where_clause(db)]
        if (ex_clause = exclusion_clause(db)).present?
          filter_clause &= ~Sequel[ex_clause]
        end
        filter_clause
      end

      def criterion_table
        dm.table_by_domain(domain)
      end

      # The condition that selects this vocabulary's rows. where_clause
      # includes it, so Union can name every merged vocabulary in one IN list.
      def vocabulary_condition
        { clinical_code_vocabulary_id: vocabulary_id }
      end

      def vocabulary_id
        @vocabulary_id ||= translated_vocabulary_id
      end

      private

      def query(db)
        ds = db[criterion_table]

        ds = ds.where(filter_clause(db))

        unless (more_columns = additional_columns(db)).empty?
          ds = ds.select_append(*more_columns)
        end

        ds
      end

      def exclusion_clause(_db)
        {}
      end

      def additional_columns(_db)
        []
      end

      def where_clause(db)
        # We're probably going to partition the observations table by clinical_code_vocabulary_id,
        # for Spark, so this will create queries that leverage that partitioning
        # and it shouldn't hurt for PostgreSQL performance
        wheres = vocabulary_condition

        unless select_all?
          concept_ids = dm.concept_ids(db, vocabulary_id, arguments, check_case: false)

          wheres = wheres.merge({ clinical_code_concept_id: concept_ids })
        end

        wheres
      end

      def query_cols
        dm.table_columns(source_table)
      end

      def select_all?
        arguments.include?("*")
      end

      def preferred_name
        vocab_entry.short_name || vocab_entry.omopv5_id
      end

      # Defined so that bad_arguments can check for bad codes
      def code_regexp
        unless defined?(@code_regexp)
          @code_regexp = nil

          if (format = Vocabularies::Formats.regexp(vocab_entry.omopv5_id))
            @code_regexp = Regexp.union(format, /\A\*\Z/)
          end
        end
        @code_regexp
      end

      def bad_format_message
        vocab_entry.omopv5_id == "NDC" ? NDC_BAD_FORMAT : BAD_FORMAT
      end

      def translated_vocabulary_id
        vocab_entry.omopv5_vocabulary_id || op_name
      end

      def domain_map(_v_id)
        (vocab_entry.domain || :condition_occurrence).to_sym
      end

      def table_is_missing?(db)
        dm.table_is_missing?(db)
      end
    end
  end
end
