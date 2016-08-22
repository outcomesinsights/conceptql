require_relative 'vocabulary_operator'

module ConceptQL
  module Operators
    # A StandardVocabularyOperator is a superclass for a operator that represents a criterion whose column stores information associated with a standard vocabulary.
    #
    # If that seems confusing, then think of CPT or SNOMED criteria.  That type of criterion takes a set of values that live in the OMOP concept table.
    #
    # My coworker came up with a nice, generalized query that checks for matching concept_ids and matching source_code values.  This class encapsulates that query.
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
    class StandardVocabularyOperator < VocabularyOperator

      def query(db)
        ds = db.from(table_name)
          .where(conditions(db))
        if omopv4?
          ds = ds.join(:concept___c, c__concept_id: table_concept_column)
        end
        ds
      end

      def query_cols
        table_columns(table_name, :concept)
      end

      def conditions(db)
        if omopv4?
          {c__concept_code: arguments_fix(db), c__vocabulary_id: vocabulary_id}
        else
          conditions = { code_column => arguments_fix(db) }
          conditions[vocabulary_id_column] = vocabulary_id if vocabulary_id_column
          conditions
        end
      end

      def describe_code(db, code)
        db[:concept].filter(:vocabulary_id => vocabulary_id).filter(:concept_code => code).map(:concept_name)[0]
      end

      private

      def validate(db)
        super
        if add_warnings?(db)
          args = arguments.dup
          args -= bad_arguments
          missing_args = args - db[:concept].where(:vocabulary_id=>vocabulary_id, :concept_code=>arguments_fix(db, args)).select_map(:concept_code)
          unless missing_args.empty?
            add_warning("unknown concept code", *missing_args)
          end
        end
      end
    end
  end
end

