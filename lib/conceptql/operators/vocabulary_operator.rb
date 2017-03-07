require_relative 'operator'
require_relative '../code_list_item'

module ConceptQL
  module Operators
    class VocabularyOperator < Operator
      category "Select by Clinical Codes"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def domain
        table
      end

      def code_list(db)
        [arguments.map do |code|
          CodeListItem.new(self.class.preferred_name, code, describe_code(db, code))
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
