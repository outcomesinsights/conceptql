# frozen_string_literal: true

require "json"
require "forwardable"
require_relative "scope"
require_relative "nodifier"
require_relative "one_query_counts"
require_relative "annotation"
require "sequel/sqlformat"

module ConceptQL
  class Query
    class QueryError < StandardError
      def message
        return super unless cause

        og_message = if cause.respond_to?(:full_message)
                       cause.full_message
        else
                       ([ cause.message ] + cause.backtrace).join("\n")
        end
        [ super, "OG ERROR:", og_message ].join("\n")
      end
    end
  end

  # Raised when a Query builds the SQL of a statement (#query, #sql,
  # #sql_statements, and #all, #count, #execute, #order and #analyze through
  # #query) or its code list (#code_list), and the statement has validation
  # errors. An invalid statement can crash while it builds, or build SQL that
  # silently returns fewer rows. Warnings do not raise.
  #
  # #errors is the list of every error that annotate shows, in the form of
  # ConceptQL::Annotation#errors ({ operator:, id:, message:, details: }), so
  # two operators with the same name keep their own errors. #statement is the
  # statement that the Query holds.
  class InvalidStatementError < Query::QueryError
    attr_reader :statement, :errors

    def initialize(statement, errors)
      @statement = statement
      @errors = errors
      super([ "Invalid ConceptQL statement. Validation errors:",
             *errors.map { |error| "  #{error[:operator]}: #{describe(error)}" },
             "Statement: #{statement.inspect}" ].join("\n"))
    end

    private

    def describe(error)
      details = error[:details]
      details.empty? ? error[:message].to_s : "#{error[:message]} (#{details.flatten.map(&:to_s).join(', ')})"
    end
  end

  class Query
    # The name of InvalidStatementError in 0.4.0 to 0.5.0.
    InvalidStatementError = ConceptQL::InvalidStatementError

    extend Forwardable
    def_delegators :query, :all, :count, :execute, :order
    def_delegators :cdb, :db

    attr_reader :statement

    def initialize(cdb, statement, opts = {})
      @cdb = cdb
      @given_statement = statement
      @statement, opts = extract_statement(statement, opts)
      @opts = opts
      opts[:algorithm_fetcher] ||= proc do |alg|
        statement, description = db[:concepts].where(concept_id: alg).get(%i[statement label])
        statement = JSON.parse(statement) if statement.is_a?(String)
        [ statement, description ]
      end
      @nodifier = opts[:nodifier] || Nodifier.new(cdb, { database_type: cdb.database_type }.merge(opts))
    end

    def analyze
      query(explain: true, analyze: true).analyze
    end

    # Raises InvalidStatementError if the statement has validation errors.
    def query(opts = {})
      validate!
      (@queries ||= {})[opts] ||= nodifier.scope.with_ctes(operator, db, opts)
    end

    def query_cols(opts = {})
      cols = operator.dynamic_columns
      if opts[:cast]
        cols = query_cols.to_h do |column|
          [ column, operator.cast_column(column) ]
        end
      end
      cols
    end

    def column_names
      query_cols.is_a?(Hash) ? query_cols.keys : query_cols
    end

    def sql(*args)
      sql_statements(*args).values.join(";\n")
    end

    def sql_statements(*args)
      stmts = query.sql_statements

      if args.include?(:create_tables)
        sql = stmts.delete(:query)
        drop_stmts = []
        if args.include?(:drop_tables)
          drop_stmts = stmts.map do |name, _|
            [ [ "drop", name ].join("_"), db.send(:drop_table_sql, name, if_exists: true) ]
          end
        end
        create_stmts = stmts.map do |name, sql|
          [ name, db.send(:create_table_as_sql, name, sql, {}) ]
        end
        stmts = drop_stmts + create_stmts
        stmts.push([ :query, sql ])
      end

      if args.include?(:formatted)
        stmts = stmts.map do |name, sql|
          [ name, format(sql) ]
        end
      end
      Hash[stmts]
    rescue InvalidStatementError
      raise
    rescue StandardError
      raise QueryError, "Failed to generate SQL for #{statement.inspect}"
    end

    # The statement, with an annotation hash in each operator: its effective
    # id (see Annotation.assign_ids), its counts, errors and warnings. With
    # counts on, DuckDB and Postgres count every operator with one SQL
    # statement (OneQueryCounts). ConceptQL::Annotation reads the result.
    #
    # The Query keeps one result for each opts hash, so a repeated call with
    # the same opts annotates once. Operators memoize #annotate and write into
    # their own options, so each opts hash gets a fresh operator tree, and a
    # call with other opts gets its own correct result.
    #
    # A window statement keeps its window operator at the top, and a window
    # table that is a ConceptQL statement is annotated in place, in the
    # window_table option of the window operator, so each of its errors stays
    # on its own operator. When the window table has errors, the outer
    # statement is not counted, because every count joins the window table,
    # and building its SQL raises.
    def annotate(opts = {})
      annotated_tree(opts).annotated
    end

    # The errors of the statement, as ConceptQL::Annotation#errors gives them.
    # They come from the kept annotation with skip_counts: true, so no count
    # SQL runs.
    def errors
      annotation.errors
    end

    # The warnings of the statement, as ConceptQL::Annotation#warnings gives
    # them, from the same kept annotation as #errors.
    def warnings
      annotation.warnings
    end

    # True when no operator has an error. Warnings do not make a statement
    # invalid.
    def valid?
      annotation.valid?
    end

    def accept(visitor, _opts = {})
      operator.accept(visitor)
    end

    def extract_metadata
      visitor = ConceptQL::Visitors::MetadataExtractor.new
      operator.accept(visitor)
      visitor.results
    end

    def domains
      operator.domains(db)
    end

    def events_per_patient
      operator.events_per_patient
    end

    def multiple_vocabularies
      operator.multiple_vocabularies
    end

    def operator
      @operator ||= if statement.is_a?(Array)
                      if statement.first.is_a?(Array)
                        Operators::Invalid.new(nodifier, "invalid", errors: [ [ "incomplete statement" ] ])
                      else
                        nodifier.create(*statement)
                      end
      else
                      Operators::Invalid.new(nodifier, "invalid",
                                             errors: [ [ "invalid root operator", statement.inspect ] ])
      end
    end

    def rdbms
      operator.rdbms
    end

    # Raises InvalidStatementError if the statement has validation errors:
    # the operator tree of an invalid statement can have missing operands,
    # and a partial code list would look complete. Warnings do not raise.
    def code_list(_ignored_db = nil)
      validate!
      operator.code_list(db).uniq
    end

    # Every error of the statement, the check that callers use to decide
    # whether a statement is valid. It is #errors: it reads the kept
    # annotation with skip_counts: true, so it never runs count SQL. #sql
    # calls it.
    def validation_errors
      errors
    end

    def drop_temp_tables(opts = {})
      query.drop_temp_tables(opts)
    end

    protected

    attr_reader :nodifier, :annotated

    # Annotates this Query's own operator tree once. Only #annotated_tree
    # calls it, on a fresh Query.
    def annotate_own_tree(opts)
      @annotated = Annotation.assign_ids(annotate_without_ids(opts))
    end

    # The annotated statement before Annotation.assign_ids, so that the ids
    # of a window table statement are assigned with the ids of the statement
    # around it. It annotates this Query's own operator tree, so only a fresh
    # Query calls it.
    def annotate_without_ids(opts)
      opts = opts.merge(skip_counts: true) unless window_table_errors.empty? && window_option_errors.empty?
      nodifier.scope.one_query_counts = OneQueryCounts.new(operator, db, opts)
      with_window(operator.annotate(db, opts), opts)
    end

    private

    attr_reader :cdb

    # A fresh Query of the given statement (with its window operator) for
    # each opts hash, with its own operator tree and scope, that has annotated
    # its tree with those opts. This Query's own tree is never annotated, so
    # #query and #sql do not depend on annotate calls.
    def annotated_tree(opts)
      (@annotated_trees ||= {})[opts.dup] ||= Query.new(cdb, @given_statement, @opts).tap do |tree|
        tree.annotate_own_tree(opts)
      end
    end

    def annotation
      Annotation.new(annotate(skip_counts: true))
    end

    # Raises InvalidStatementError if #validation_errors is not empty. The
    # statement and the opts of a Query do not change, so it checks once.
    # Warnings do not raise. cause: nil keeps an error that a caller is
    # handling out of the message (QueryError#message prints the cause).
    def validate!
      return if @valid

      errors = validation_errors
      raise InvalidStatementError.new(statement, errors), cause: nil unless errors.empty?

      @valid = true
    end

    # The window options of the scope, as Scope#windows reads them: the
    # scope options of the calling program, merged with the options of the
    # statement's window
    def window_opts
      scope_opts = nodifier.scope.opts
      scope_opts.merge(scope_opts[:window_opts] || {})
    end

    # The window table of the scope, as Window::Table reads it: a table name
    # or a ConceptQL statement (an Array)
    def window_table
      window_opts[:window_table]
    end

    # The errors of the window options (Window.option_errors), as
    # [message, *details]. The window operator of the annotation has them.
    def window_option_errors
      Window.option_errors(window_opts)
    end

    # The validation errors of the window table's statement, when the window
    # table is a ConceptQL statement, as one list of [message, *details]. Each
    # message starts with the name of the operator that reported it. A table
    # name has no errors.
    def window_table_errors
      return [] unless window_table.is_a?(Array)

      cdb.query(window_table).validation_errors.map do |error|
        [ "#{error[:operator]}: #{error[:message]}", *error[:details] ]
      end
    end

    # The options of the statement's window, as the scope runs them: for a
    # window inside a window, the options of the inner window. Nil when the
    # statement is not a window statement.
    def statement_window_options
      nodifier.scope.opts[:window_opts]&.except(:cdb) if @window_statement
    end

    # The annotated statement inside its window operator, when the statement
    # is a window statement, the scope's window table is a statement, or the
    # window options have errors. The window operator has the options of the
    # statement's window (statement_window_options) and an annotation hash,
    # which holds its id and the errors of the window options. A window table
    # statement is annotated in place, with the same opts.
    def with_window(annotated, opts)
      table = window_table
      errors = window_option_errors
      window_options = statement_window_options
      return annotated unless window_options || table.is_a?(Array) || errors.any?

      options = (window_options || {}).dup
      options[:window_table] = cdb.query(table).annotate_without_ids(opts) if table.is_a?(Array)
      [ "window", annotated, options.merge(annotation: errors.empty? ? {} : { errors: errors }) ]
    end

    def extract_statement(stmt, opts)
      if !stmt.is_a?(Array)
        raise "Improper ConceptQL statement: Expected an Array, got a #{stmt.class}"
      elsif stmt.first.to_s == "window"
        raise "window operator needs a hash as the last item of the array." unless stmt.last.is_a?(Hash)
        unless stmt.length == 3
          raise "window operator needs a ConceptQL statement followed by a hash as the last item of the array."
        end

        # The options of an inner window replace those of an outer window.
        opts[:scope_opts] = (opts[:scope_opts] || {})
        opts[:scope_opts].merge!(window_opts: stmt.last.merge(cdb: cdb))
        @window_statement = true
        extract_statement(stmt[1], opts)
      elsif stmt.length == 1 && stmt.first.is_a?(Array)
        extract_statement(stmt.first, opts)
      else
        [ stmt, opts ]
      end
    end

    # Formats inside the Ruby process with the sequel-sqlformat gem (the Rust
    # sqlformat crate). It changes only whitespace and keyword case, and it never
    # fails on unknown syntax, so DuckDB and Spark SQL format too.
    def format(sql)
      Sequel::SQLFormat.format(sql, dialect: Sequel::SQLFormat.dialect_for(cdb.database_type), indent: 2, uppercase: true)
    end
  end
end
