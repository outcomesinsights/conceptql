require "sequelizer"
require_relative "vocabulary_operator"
require "csv"

module ConceptQL
  module Operators
    class Vocabulary < VocabularyOperator
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
          @assigned_vocabularies ||= all_vocabs.select { |k, vocab| vocab[:hidden].nil? }
        end

        def vocab_domain
          each_vocab.each_with_object({}) do |row, h|
            h[row[:id]] = row[:domain]
          end
        end

        def register_many
          assigned_vocabularies.each do |name, vocab|
            dms = [:gdm]
            dms << :omopv4_plus if ConceptQL::Utils.present?(vocab[:domain])
            register(name, *dms)
          end
        end

        def all_vocabs
          @all_vocabs ||= each_vocab.each_with_object({}) do |row, h|
            h[row[:id]] = row.to_hash
          end
        end

        def each_vocab
          @each_vocab ||= get_all_vocabs
        end

        def get_all_vocabs
          [ConceptQL.vocabularies_file_path, ConceptQL.custom_vocabularies_file_path].select(&:exist?).map do |path|
            CSV.foreach(path, headers: true, header_converters: :symbol).to_a
          end.inject(:+)
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
          h[:predominant_domains] = [vocab[:domain]].flatten
          h
        end
      end

      register_many

      desc 'Returns all records that match the given codes for the given vocabulary'
      argument :codes, type: :codelist
      validate_codes_match

      def query(db)
        ds = db[dm.table_by_domain(domain)]

        ds = ds.where(where_clause(db))
        if gdm?
          ds = ds.select_append(Sequel.cast_string(domain.to_s).as(:criterion_domain))
        end
        ds
      end

      def where_clause(db)
        if gdm?
          where_conds = {vocabulary_id: vocabulary_id}
          where_conds[:concept_code] = arguments.flatten unless select_all?
          concept_ids = db[:concepts].where(where_conds).select(:id)
          { clinical_code_concept_id: concept_ids }
        else
          conds = { dm.source_vocabulary_id(domain) => vocabulary_id.to_i }
          conds[dm.source_value_column(domain)] = arguments unless select_all?
          conds
        end
      end

      def domain
        domain_map(op_name)
      end

      def table
        domain_map(op_name)
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
            lexicon.concepts(vocabulary_id, codes).select_map([:concept_code, :concept_text])
          end
          return codes.zip([])
        end
        results = dm.concepts_ds(db, vocabulary_id, codes).select_map([:concept_code, :concept_text])
        remaining_codes = codes - results.map(&:first).map(&:to_s)
        (results + remaining_codes.zip([])).sort_by(&:first)
      end

      def select_all?
        arguments.include?("*")
      end

      def preferred_name
        self.class.all_vocabs[op_name][:vocabulary_short_name] || vocab[:id]
      end

      private

      def vocab_entry
        self.class.all_vocabs[op_name] || {format_regexp: ""}
      end

      # Defined so that bad_arguments can check for bad codes
      def code_regexp
        unless defined?(@code_regexp)
          @code_regexp = nil

          if reg_str = vocab_entry[:format_regexp]
            @code_regexp = Regexp.new(reg_str, Regexp::IGNORECASE)
          end
        end
        @code_regexp
      end

      def vocabulary_id
        @vocabulary_id ||= translated_vocabulary_id
      end

      def translated_vocabulary_id
        return op_name if gdm?
        return translate_to_old(op_name)
      end

      def translate_to_old(v_id)
        v = self.class.v5_vocab_to_v4_vocab[v_id.to_s]
        return v.to_i if v
        v
      end

      def domain_map(v_id)
        (self.class.vocab_domain[v_id] || :condition_occurrence).to_sym
      end

      def table_is_missing?(db)
        dm.table_is_missing?(db)
      end
    end
  end
end

