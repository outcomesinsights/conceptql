require_relative "operator"

module ConceptQL
  module Operators
    class Vocabulary < Operator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister

      category "Select by Clinical Codes"
      basic_type :selection
      desc 'Selects records based on the given vocabulary.'
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

          missing_args = args - dm.known_codes(db, vocabulary_id, args)

          unless missing_args.empty?
            add_warning("unknown code(s)", *missing_args)
          end
        end
      end

      def describe_codes(db, codes)
        return [["*", "ALL CODES"]] if select_all?
        found_codes = dm.concepts_to_codes(db, vocabulary_id, codes)

        found_codes + (codes - found_codes.map(&:first)).zip([])
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
        # We're probably going to partition the observations table by clinical_code_vocabulary_id,
        # for Spark, so this will create queries that leverage that partitioning
        # and it shouldn't hurt for PostgreSQL performance
        wheres = { clinical_code_vocabulary_id: vocabulary_id }

        if !select_all?
          concept_ids = dm.concepts(db, vocabulary_id, arguments).select_map(:id)

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


