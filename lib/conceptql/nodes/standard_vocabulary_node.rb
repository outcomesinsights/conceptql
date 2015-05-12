require_relative 'operator'

module ConceptQL
  module Nodes
    # A StandardVocabularyNode is a superclass for a node that represents a criterion whose column stores information associated with a standard vocabulary.
    #
    # If that seems confusing, then think of CPT or SNOMED criteria.  That type of criterion takes a set of values that live in the OMOP concept table.
    #
    # My coworker came up with a nice, gneralized query that checks for matching concept_ids and matching source_code values.  This class encapsulates that query.
    #
    # Subclasses must provide the following methods:
    # * table
    #   * The CDM table name where the criterion will fetch its rows
    #   * e.g. for CPT, this would be procedure_occurrence
    # * concept_column
    #   * Name of the column in the table that stores a concept_id related to the criterion
    #   * e.g. for CPT, this would be procedure_concept_id
    # * vocabulary_id
    #   * The vocabulary ID of the source vocabulary for the criterion
    #   * e.g. for CPT, a value of 4 (for CPT-4)
    class StandardVocabularyNode < Operator
      category 'Standard Vocabulary'
      category 'Code Lists'
      def query(db)
        db.from(table_name)
          .join(:vocabulary__concept___c, c__concept_id: table_concept_column)
          .where(c__concept_code: values, c__vocabulary_id: vocabulary_id)
      end

      def type
        table
      end
      private

      def table_name
        @table_name ||= make_table_name(table)
      end

      def table_concept_column
        "tab__#{concept_column}".to_sym
      end
    end
  end
end

