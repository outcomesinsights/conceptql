# frozen_string_literal: true

require_relative "pass_thru"

module ConceptQL
  module Operators
    # Represents a operator that will either:
    # - create a value_as_number value for every person in the database
    # - change the value_as_number value for every every record passed in
    #   - either to a number
    #   - or a value from a column in the origin row
    #
    # Accepts two params:
    # - Either a number value or a symbol representing a column name
    # - An optional stream
    class Numeric < PassThru
      register __FILE__
      # "We do not yet support numeric or sum in any meaningful way"
      # (Ryan, 2026-11-03, seed conceptql-mdo.4)
      hidden
      category "Modify Data"

      desc "Sets the value_as_number of each record of its upstream stream. " \
           "The argument is a number, or the name of a column whose value is copied from the same record. " \
           "Without an upstream stream, the operator selects one person record for each person, " \
           "with value_as_number set to the argument. " \
           "A column name must then name a column of the person table."
      argument :value, type: :float
      allows_one_upstream
      validate_at_most_one_upstream
      validate_one_argument
      default_query_columns
      require_column :value_as_number

      def query(db)
        stream.nil? ? as_criterion(db) : with_kids(db)
      end

      def domains(db)
        stream.nil? ? [ :person ] : super
      end

      # Without an upstream, Numeric emits exactly one row per patient via the
      # as_criterion path (SELECT value_as_number FROM patients). The leaf
      # default in Operator#events_per_patient assumes :multiple, which is wrong
      # for this single-row-per-patient shape. Override here so that downstream
      # operators (Union, etc.) can correctly conclude that a numeric leaf is
      # single-event-per-patient.
      def events_per_patient
        stream.nil? ? :single : super
      end

      private

      # A column name in the argument must be a column of the rows it is read
      # from, or the statement fails at run time. The match ignores case,
      # because DuckDB and Spark resolve an identifier without regard to case,
      # and such a statement runs on them today.
      def additional_validation(_db, _opts = {})
        name = column_argument
        return if name.nil? || matched_column

        add_error("unknown column", name)
      end

      # The column that the argument names, spelled as the rows spell it, or
      # nil when the argument names no readable column. The SQL quotes the
      # name, and Postgres folds only unquoted names, so the SQL must use this
      # spelling for a match in another case to run there too.
      def matched_column
        name = column_argument
        name && readable_columns.find { |column| column.to_s.casecmp?(name) }
      end

      # With an upstream, a column name is read from the upstream's rows
      # (SELECT ... FROM (<upstream>)), not from the tables the upstream
      # reads. Every stream emits the same columns, the scope's query columns,
      # so one check covers an upstream that mixes tables, such as a union of
      # two domains. Without an upstream, the name is read from the person
      # table that as_criterion selects from, so it must be one of that
      # table's columns in the data model's schema.
      def readable_columns
        return scope.query_columns if stream

        dm.table_cols(dm.table_by_domain(:person))
      end

      def with_kids(db)
        dm.selectify(db.from(stream.evaluate(db)), replace: { value_as_number: first_argument })
      end

      def as_criterion(db)
        # Explicitly set column_family to DEFAULT_COLUMN_FAMILY here. The
        # selectify path through `domain: :person` runs against the patients
        # table, which doesn't have a column_family column. Without this
        # replace, nullified_columns inserts CAST(NULL AS text) AS
        # "column_family", and the outer evaluate -> select_it wrapper does not
        # re-inject a value (Numeric has no source_table/table/domain methods,
        # so determine_table returns nil and select_it's `cf =
        # DEFAULT_COLUMN_FAMILY` branch never fires). Result: every Numeric
        # as_criterion row carried column_family = NULL. Explicitly replacing
        # it here keeps the fix at the same level as Episode#query, which
        # already sets column_family in its replace hash for the same reason.
        dm.selectify(db.from(dm.table_by_domain(:person)),
                     domain: :person,
                     replace: {
                       value_as_number: first_argument,
                       column_family: ConceptQL::Scope::DEFAULT_COLUMN_FAMILY
                     })
      end

      def first_argument
        value = argument_text
        if !value || is_a_number?(value)
          Sequel.cast_numeric(value, Float)
        else
          Sequel.identifier(matched_column || value)
        end
      end

      def argument_text
        value = arguments.first.to_s.strip
        value.blank? ? nil : value
      end

      # The argument when it names a column, or nil when it is a number or blank
      def column_argument
        value = argument_text
        value if value && !is_a_number?(value)
      end

      def is_a_number?(value)
        value =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
      end
    end
  end
end
