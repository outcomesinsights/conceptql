require_relative 'operator'

module ConceptQL
  module Operators
  	class VocabularyOperator < Operator
      category "Select by Clinical Codes"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument
      ConceptCode = Struct.new(:vocabulary, :code, :description) do
      	def to_s
          "#{vocabulary} #{code}: #{description}"
        end
      end

      def domain
        table
      end

      def code_list(db)
        [self.arguments.map do | code |
          ConceptCode.new(self.class.name.split('::').last, code, self.describe_code(db, code))
        end]
      end

      private

      def code_column
        table_source_value(table_name)
      end

      def vocabulary_id_column
        table_vocabulary_id(table_name)
      end

      def table_name
        @table_name ||= make_table_name(table)
      end

      def table_concept_column
        "tab__#{concept_column}".to_sym
      end
  	end
  end
end