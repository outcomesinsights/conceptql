# frozen_string_literal: true

require_relative "vocabulary"

module ConceptQL
  module Operators
    class MultipleVocabularies < Operator
      include ConceptQL::Behaviors::Windowable
      include ConceptQL::Behaviors::CodeLister
      extend Vocabulary::SharedDocumentation

      class << self
        def multiple_vocabularies
          @multiple_vocabularies ||= get_multiple_vocabularies
        end

        def get_multiple_vocabularies
          [ ConceptQL.multiple_vocabularies_file_path,
           ConceptQL.custom_multiple_vocabularies_file_path ].select(&:exist?).map do |path|
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

        def long_name_of(vocabulary_ids)
          return vocabulary_ids.first if vocabulary_ids.one?

          "#{vocabulary_ids[0...-1].join(', ')} and #{vocabulary_ids.last}"
        end

        def operator_symbol(word)
          word.gsub(/\W+/, "_").downcase
        end

        # This will override the to_metadata method and return the preferred name
        # based on the name listed in the file. The long_name names the
        # operator's vocabularies, for example "CPT4, HCPCS and CPT4_HCPCS".
        #
        # This method will be called once for each vocabulary we register
        # for this operator
        def to_metadata(name, opts = {})
          h = super
          op_info = multiple_vocabularies[name].first
          h[:preferred_name] = op_info[:operator]
          h[:long_name] = long_name_of(multiple_vocabularies[name].map { |mv| mv[:vocabulary_id] })
          h[:predominant_domains] = multiple_vocabularies[name].map { |mv| mv[:domain] }.uniq.compact
          h
        end
      end

      register_many

      desc "Selects records based on the given vocabularies."
      argument :codes, type: :codelist,
                       meaning: "One or more codes. The operator looks up each code in each of its vocabularies " \
                                "(CPT-4 and HCPCS for cpt_or_hcpcs) and selects the matching records of all of them. " \
                                "A code gets a warning only when every one of the vocabularies rejects it."
      basic_type :selection
      effects :select
      category "Select by Clinical Codes"
      validate_no_upstreams
      validate_at_least_one_argument
      conceptql_spec_id "vocabulary"

      def query(db)
        # TODO: A much-more efficient method would be to find all those vocabs
        # sharing a common table and feed them into a single single query,
        # but I think this would require some revamping of Vocabulary, and I'm
        # just not interested in taking that on right now.
        all = disjoint_vocabularies?
        vocab_ops.map { |vo| vo.evaluate(db) }.inject do |union, q|
          union.union(q.from_self, all: all)
        end
      end

      # Each vocabulary operator selects only the rows whose vocabulary column
      # holds its own vocabulary. A row holds one vocabulary, and each output
      # row carries its source row's id as criterion_id, so operators with
      # different vocabularies on one column never produce the same row. Then
      # UNION ALL skips a duplicate removal that is expensive on large data
      # (conceptql-5pz). A repeated row inside one branch now passes through,
      # as it does for a single vocabulary operator and for union. A custom
      # file can list one vocabulary twice, so those branches keep UNION.
      def disjoint_vocabularies?
        conditions = vocab_ops.map(&:vocabulary_condition)
        conditions.map(&:keys).uniq.length == 1 && conditions.uniq.length == conditions.length
      end

      def domains(_db)
        vocab_ops.map(&:domain).uniq
      end

      # Each vocabulary operator in vocab_ops has already applied the scope's
      # windows. Applying them again to the union multiplied rows: an event in
      # k overlapping windows came out k*k times instead of k (conceptql-7cd).
      def skip_windows?
        true
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

      # The per-code warnings a Vocabulary operator gives, from most to least
      # specific (Operator::BAD_FORMATS, Vocabulary::NOT_PRESENT_IN_DATASET,
      # Operator::UNKNOWN_CODE). This operator checks its codes itself (see
      # #code_warnings), so it drops these warnings of its vocabulary
      # operators.
      CODE_WARNINGS = [ *BAD_FORMATS, Vocabulary::NOT_PRESENT_IN_DATASET, UNKNOWN_CODE ].freeze

      # The operator checks its codes as one set across its vocabularies
      # (bead conceptql-0h2n). When etl_vocabulary_ids lists none of its
      # vocabularies, it gives the no-records warning and null counts, and
      # its codes get no not-present warning, as a Vocabulary operator's do
      # (bead conceptql-dufi). The other warnings of its vocabulary operators
      # appear only when every one of them gives the warning with the same
      # details (#aggregate_messages).
      def additional_validation(db, opts = {})
        @no_records_in_data = add_warnings?(db, opts) && vocab_ops.all? { |vo| vo.absent_from_data?(db) }
        inner_opts = opts.merge(skip_merged_vocabulary_check: true)
        vocab_ops.each { |vo| vo.valid?(db, inner_opts) }

        @errors += aggregate_messages(vocab_ops.map(&:errors))
        @warnings += aggregate_messages(vocab_ops.map { |vo| vo.warnings.reject { |w| CODE_WARNINGS.include?(w.first) } })
        add_warning(Vocabulary::NO_RECORDS_IN_DATA) if @no_records_in_data
        @warnings += code_warnings(db, opts)
      end

      def no_records_in_data?(db, opts = {})
        validate(db, opts)
        @no_records_in_data || false
      end

      # A code is improperly formatted when every vocabulary rejects its
      # format. (12345 is badly formatted for HCPCS but has the format of
      # CPT4, so it is checked.) Database#check_codes sorts the other codes
      # across all of the vocabularies: a code is known when the Database's
      # lexicon has it in any of them, and the 2020 rule applies only when no
      # lexicon has a concept of any of them. With no records of the
      # vocabularies in the data, the not-present warning is not given. Each
      # warning lists every code.
      def code_warnings(db, opts = {})
        return [] if arguments.include?("*")

        codes = arguments.uniq
        bad_format = codes.select { |code| vocab_ops.all? { |vo| vo.bad_arguments.include?(code) } }
        checked = codes - bad_format
        not_present, unknown = lexicon_checks?(opts) ? nodifier.cdb.check_codes(db, vocab_ops.map(&:vocabulary_id), checked) : [ [], [] ]
        not_present = [] if @no_records_in_data

        [ [ BAD_FORMAT, *bad_format ], [ Vocabulary::NOT_PRESENT_IN_DATASET, *not_present ], [ UNKNOWN_CODE, *unknown ] ]
          .reject { |warning| warning.length == 1 }
      end

      def aggregate_messages(message_sets)
        messages = message_sets.map do |message_set|
          message_set.to_h { |message, *args| [ message, args ] }
        end

        messages_keys = messages.map(&:keys).inject(:|)

        messages = messages_keys.each.with_object({}) do |key, h|
          h[key] = messages.map { |w| w[key] || [] }.inject(:&)
        end

        messages = messages.reject { |_, v| v.empty? }

        messages.map { |k, v| [ k, *v ] }
      end

      def describe_codes(db, codes)
        codes = vocab_ops.flat_map do |vo|
          vo.describe_codes(db, codes)
        end

        # The first vocabulary that describes a code wins, so CPT4_HCPCS adds
        # descriptions only for codes that CPT4 and HCPCS do not know.
        codes_with_descriptions = codes.select(&:last).uniq(&:first)
        codes_without_descriptions = codes.reject(&:last).map(&:first)
        codes_without_descriptions -= codes_with_descriptions.map(&:first)
        codes_with_descriptions + codes_without_descriptions.zip([])
      end

      # An optional vocabulary (CPT4_HCPCS) has an operator only on a Database
      # whose lexicon carries it, so it is skipped elsewhere. A required one
      # that is missing still raises.
      def vocab_ops
        @vocab_ops ||= self.class.multiple_vocabularies[op_name].filter_map do |op_info|
          name = op_info[:vocabulary_id].to_s.downcase
          next if op_info[:optional] == "yes" && !nodifier.operators.key?(name)

          nodifier.operators.fetch(name).new(nodifier, name, *arguments)
        end
      end

      def preferred_name
        self.class.multiple_vocabularies[op_name].first[:operator]
      end
    end
  end
end
