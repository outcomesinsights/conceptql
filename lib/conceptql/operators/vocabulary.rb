require_relative "operator"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister

      category "Select by Clinical Codes"
      basic_type :selection
      desc 'Returns all records that match the given codes for the given vocabulary'
      validate_no_upstreams
      validate_at_least_one_argument
      validate_codes_match

      def select_all?
        arguments.include?("*")
      end

      def source_table
        domain_map(op_name)
      end

      def table
        domain_map(op_name)
      end

      def domain
        domain_map(op_name)
      end

      def domains(db)
        vocab_entry.predominant_domains.map(&:to_sym)
      end

      def additional_validation(db, opts = {})
        if add_warnings?(db, opts) && !select_all?
          args = arguments.dup
          args -= bad_arguments
          missing_args = []

          if no_db?(db, opts)
            with_lexicon do |lexicon|
              missing_args = args - lexicon.known_codes(vocabulary_id, args)
            end
          else
            missing_args = args - dm.known_codes(db, vocabulary_id, args)
          end

          unless missing_args.empty?
            add_warning("unknown code(s)", *missing_args)
          end
        end
      end

      def describe_codes(db, codes)
        return [["*", "ALL CODES"]] if select_all?
        found_codes = []
        if no_db?(db)
          with_lexicon do |lexicon|
            found_codes = lexicon.concepts(vocabulary_id, codes).select_map([:concept_code, :concept_text])
          end
          return found_codes + (codes - found_codes.map(&:first)).zip([])
        end
        results = dm.concepts_ds(db, vocabulary_id, codes).select_map([:concept_code, :concept_text])
        remaining_codes = codes - results.map(&:first).map(&:to_s)
        (results + remaining_codes.zip([])).sort_by(&:first)
      end

      def filter_clause(db)
        filter_clause = Sequel[where_clause(db)]
        if (ex_clause = exclusion_clause(db)).present?
          filter_clause = filter_clause.&(~Sequel[ex_clause])
        end
        filter_clause
      end

      def criterion_table
        dm.table_by_domain(domain)
      end

      private

      def code_column
        dm.table_source_value(table_name)
      end

      def vocabulary_id_column
        dm.source_vocabulary_id(table_name)
      end

      def table_name
        @table_name ||= make_table_name(table)
      end

      def table_concept_column
        Sequel.qualify(:tab, concept_column)
      end

      def query(db)
        ds = db[criterion_table]

        ds = ds.where(filter_clause(db))

        unless (more_columns = additional_columns(db)).empty?
          ds = ds.select_append(*more_columns)
        end

        ds
      end

      def exclusion_clause(db)
        {}
      end

      def additional_columns(db)
        []
      end

      def where_clause(db)
        return { clinical_code_vocabulary_id: vocabulary_id } if select_all?

        where_conds = {vocabulary_id: vocabulary_id}
        where_conds[:concept_code] = arguments
        concept_ids = db[:concepts].where(where_conds).select(:id)

        { clinical_code_concept_id: concept_ids }
      end

      def query_cols
        dm.table_columns(:clinical_codes)
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

          if reg_str = vocab_entry.format_regexp
            @code_regexp = Regexp.union(Regexp.new(reg_str, Regexp::IGNORECASE), /\A\*\Z/)
          end
        end
        @code_regexp
      end

      def vocabulary_id
        @vocabulary_id ||= translated_vocabulary_id
      end

      def translated_vocabulary_id
        vocab_entry.omopv5_vocabulary_id || op_name
      end

      def translate_to_old(v_id)
        v = self.class.v5_vocab_to_v4_vocab[v_id.to_s.downcase]
        return v.to_i if v
        v
      end

      def domain_map(v_id)
        (vocab_entry.domain || :condition_occurrence).to_sym
      end

      def table_is_missing?(db)
        dm.table_is_missing?(db)
      end
    end
  end
end


