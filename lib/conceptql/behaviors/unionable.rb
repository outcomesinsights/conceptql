module ConceptQL
  module Behaviors
    module Unionable
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
          uni = dup
          uni.add_vocab_ids(other.vocab_ids)
          uni.add_vocabs(other.vocabs)
          uni
        end

        def to_where_clause(db)
          clauses = []
          clauses << Sequel[clinical_code_vocabulary_id: vocab_ids] unless vocab_ids.empty?
          concepts_clause = vocabs.map { |v| v.to_where_clause(db) }.inject(:|)
          clauses << Sequel[clinical_code_concept_id: db[:concepts].where(concepts_clause).select(:id) ] if concepts_clause
          clauses.inject(:|)
        end
      end

      def unionable?
        true
      end

      def unionize(op)
        unless op.respond_to?(:wheres)
          raise "Can't unionize #{op} and #{self}"
        end

        wheres.unify(op.wheres)
        @options = @options.merge(op.options)
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

      def where_clause(db)
        wheres.to_where_clause(db)
      end
    end
  end
end
