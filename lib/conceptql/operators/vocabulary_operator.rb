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

      # This is the only method that actually populates the code_list
      #
      # For each code, we create a CodeListItem
      #
      # If code_list is passed nil for db, the description will
      # be left nil since there is no database to use to lookup descriptions
      def code_list(db)
        arguments.map do |code|
          c = CodeListItem.new(self.class.preferred_name, code, nil)
          c.description = describe_code(db, code) if db
          c
        end
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
