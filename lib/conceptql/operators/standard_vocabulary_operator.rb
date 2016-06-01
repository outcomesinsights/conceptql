require_relative 'operator'

module ConceptQL
  module Operators
    # A StandardVocabularyOperator is a superclass for a operator that represents a criterion whose column stores information associated with a standard vocabulary.
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
    class StandardVocabularyOperator < Operator
      category "Select by Clinical Codes"
      basic_type :selection
      validate_no_upstreams
      validate_at_least_one_argument

      def query(db)
        db.from(table_name)
          .where(conditions)
      end

      def query_cols
        table_columns(table_name, :concept)
      end

      def domain
        table
      end

      def conditions
        conditions = { code_column => arguments }
        conditions.merge!(vocabulary_id_column => vocabulary_id) if vocabulary_id_column
        conditions
      end

      private

      def code_column
        table_source_value(table_name)
      end

      def vocabulary_id_column
        table_vocabulary_id(table_name)
      end

      def validate(db)
        super
        if add_warnings?(db)
          missing_args = arguments - db[:concept].where(:vocabulary_id=>vocabulary_id, :concept_code=>arguments).select_map(:concept_code)
          unless missing_args.empty?
            add_warning("invalid concept code", *missing_args)
          end
        end
      end

      def table_name
        @table_name ||= make_table_name(table)
      end
    end
  end
end

