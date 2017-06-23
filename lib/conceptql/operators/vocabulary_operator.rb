require_relative 'operator'

module ConceptQL
  module Operators
    class VocabularyOperator < Operator
      include ConceptQL::Behaviors::Windowable

      category "Select by Clinical Codes"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      ConceptCode = Struct.new(:vocabulary, :code, :description) do
        def to_s
          "#{vocabulary} #{code}: #{description}"
        end
      end

      def query_cols
        tables(:clinical_codes)
      end

      def domain
        if gdm?
          vocab_op.domain
        else
          table
        end
      end

      def code_list(db)
        describe_codes(db, arguments).map do |code, desc|
          ConceptCode.new(self.class.perferred_name, code, desc)
        end
      end

      def tables
        if gdm?
          vocab_op.tables
        else
          domains
        end
      end

      def source_table
        if gdm?
          vocab_op.table
        else
          table
        end
      end

      private

      def code_column
        dm.table_source_value(table_name)
      end

      def vocabulary_id_column
        dm.table_vocabulary_id(table_name)
      end

      def table_name
        @table_name ||= make_table_name(table)
      end

      def table_concept_column
        "tab__#{concept_column}".to_sym
      end

      def vocab_op
        @vocab_op ||= Vocabulary.from_old_vocab(nodifier, vocabulary_id, *values)
      end
    end
  end
end
