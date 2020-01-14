require_relative "base"

module ConceptQL
  module Operators
    module Selection
      class Vocabulary < Base
        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::CodeLister

        category "Select by Clinical Codes"
        basic_type :selection
        desc "Returns all records that match the given codes for the given vocabulary"
        validate_no_upstreams
        validate_at_least_one_argument
        validate_codes_match

        class WhereClause

          attr_reader :vocab_ids, :vocabs

          class Vocab
            attr_reader :id, :codes

            def initialize(id, *codes)
              @id = id
              @codes = Array(codes.flatten)
            end

            def add_codes(*codes)
              @codes |= Array(codes.flatten)
            end

            def to_where_clause(db)
              Sequel[vocabulary_id: id, concept_code: codes]
            end
          end

          def initialize
            @vocab_ids = []
            @vocabs = []
          end

          def add_vocab_ids(*ids)
            @vocab_ids |= Array(ids.flatten)
          end

          def add_vocab(id, *codes)
            @vocabs << Vocab.new(id, *codes)
          end

          def add_vocabs(*other_vocabs)
            Array(other_vocabs.flatten).each do |ov|
              if existing_vocab = vocabs.find { |v| v.id == ov.id }
                existing_vocab.add_codes(ov.codes)
              else
                vocabs << ov
              end
            end
          end

          def unify(other)
            add_vocab_ids(other.vocab_ids)
            add_vocabs(other.vocabs)
          end

          def to_where_clause(db)
            clauses = []
            clauses << Sequel[clinical_code_vocabulary_id: vocab_ids] unless vocab_ids.empty?
            concepts_clause = vocabs.map { |v| v.to_where_clause(db) }.inject(:|)
            clauses << Sequel[clinical_code_concept_id: db[:concepts].where(concepts_clause).select(:id) ] if concepts_clause
            clauses.inject(:|)
          end
        end

        def select_all?
          arguments.include?("*")
        end

        def source_table
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
              if lexicon
                missing_args = args - lexicon.known_codes(vocabulary_id, args)
              end
            else
              missing_args = args - dm.concepts_ds(db, vocabulary_id, args).select_map(:concept_code) rescue []
            end

            unless missing_args.empty?
              add_warning("unknown code(s)", *missing_args)
            end
          end
        end

        def describe_codes(db, codes)
          return [["*", "ALL CODES"]] if select_all?
          if no_db?(db)
            if lexicon
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
          filter_clause
        end

        def table
          dm.nschema.cc_cql
        end

        def unionable?
          true
        end

        def unionize(op)
          unless op.respond_to?(:wheres)
            raise "Can't unionize #{op} and #{self}"
          end

          wheres.unify(op.wheres)
          self.options.merge!(op.options)
          self.required_columns |= op.required_columns
          self
        end

        def wheres
          return @wheres if defined?(@wheres)
          @wheres = WhereClause.new

          if select_all?
            @wheres.add_vocab_ids(vocabulary_id)
          else
            @wheres.add_vocab(vocabulary_id, *arguments)
          end
          @wheres
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

        def where_clause(db)
          wheres.to_where_clause(db)
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
end
