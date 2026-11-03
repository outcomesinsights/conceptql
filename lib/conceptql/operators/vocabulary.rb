# frozen_string_literal: true

require_relative "operator"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      # The vocabulary operators share one reference section (spec_id
      # vocabulary-operator): each generated vocabulary operator, read and
      # the multiple vocabulary operators. So the section's texts are written
      # on this class: `returns`, the meaning: of the codes argument, and each
      # `example`. An operator of the section extends this module and serves
      # the returns text, and only the examples whose statement starts with
      # its own name, so no operator shows an example of another one.
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
      desc "Selects records based on the given vocabulary."
      validate_no_upstreams
      validate_at_least_one_argument
      validate_codes_match

      # VocabularyClassFactory gives each vocabulary operator a copy of this
      # argument, with the label "<preferred name> Codes"
      argument :codes, type: :codelist

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

      def additional_validation(db, opts = {})
        return unless add_warnings?(db, opts) && !select_all?

        args = arguments.dup
        args -= bad_arguments

        # A statement warns about a code in another case than the stored one,
        # so its lookups do not raise CodeCaseMismatchError (bead conceptql-rz8s).
        missing_args = args - dm.known_codes(db, vocabulary_id, args, check_case: false)
        add_warning(UNKNOWN_CODE, *missing_args) unless missing_args.empty?

        warn_about_reused_codes(db, args - missing_args)
      end

      # A code that the vocabulary reused for a new meaning selects records of
      # both meanings: DRG 410 selects chemotherapy stays before 2007-10-01 and
      # biliary tract procedures after it (conceptql-ttk). Each item names the
      # code and all of its names, so the user sees the problem without a
      # vocabulary lookup.
      def warn_about_reused_codes(db, codes)
        meanings = dm.code_meanings(db, vocabulary_id, codes, check_case: false)
        reused = codes.filter_map do |code|
          names = meanings[code.downcase]
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

      def vocabulary_id
        @vocabulary_id ||= translated_vocabulary_id
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
