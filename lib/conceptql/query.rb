# frozen_string_literal: true

require "json"
require "forwardable"
require_relative "scope"
require_relative "nodifier"
require_relative "sql_formatters"

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

    # Raised by #code_list when the statement has validation errors: the
    # operator tree of an invalid statement can have missing operands, and a
    # partial code list would look complete. #errors is the errors hash of
    # #scope_annotate (operator name => list of [message, *details]).
    class InvalidStatementError < QueryError
      attr_reader :statement, :errors

      def initialize(statement, errors)
        @statement = statement
        @errors = errors
        super([ "Invalid ConceptQL statement, so it has no code list. Validation errors:",
               *errors.flat_map { |op, op_errors| op_errors.map { |e| "  #{op}: #{describe(e)}" } },
               "Statement: #{statement.inspect}" ].join("\n"))
      end

      private

      def describe(error)
        message, *details = error
        details.empty? ? message.to_s : "#{message} (#{details.flatten.map(&:to_s).join(', ')})"
      end
    end

    extend Forwardable
    def_delegators :query, :all, :count, :execute, :order
    def_delegators :cdb, :db

    attr_reader :statement

    def initialize(cdb, statement, opts = {})
      @cdb = cdb
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

    def query(opts = {})
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
    rescue StandardError
      raise QueryError, "Failed to generate SQL for #{statement.inspect}"
    end

    def annotate(opts = {})
      operator.annotate(db, opts)
    end

    def accept(visitor, _opts = {})
      operator.accept(visitor)
    end

    def extract_metadata
      visitor = ConceptQL::Visitors::MetadataExtractor.new
      operator.accept(visitor)
      visitor.results
    end

    def scope_annotate(opts = {})
      annotate(opts)
      nodifier.scope.annotation
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

    # Raises InvalidStatementError if the statement has validation errors.
    # Warnings do not raise.
    def code_list(_ignored_db = nil)
      errors = validation_errors
      raise InvalidStatementError.new(statement, errors) unless errors.empty?

      operator.code_list(db).uniq
    end

    # The errors that #scope_annotate reports, the same check that callers use
    # to decide whether a statement is valid. A fresh query runs it, because
    # operators memoize #annotate and #validate, and this query's later
    # #annotate calls must not get those results.
    def validation_errors
      Query.new(cdb, statement, @opts).scope_annotate(skip_counts: true)[:errors]
    end

    def drop_temp_tables(opts = {})
      query.drop_temp_tables(opts)
    end

    private

    attr_reader :cdb, :nodifier

    def extract_statement(stmt, opts)
      if !stmt.is_a?(Array)
        raise "Improper ConceptQL statement: Expected an Array, got a #{stmt.class}"
      elsif stmt.first.to_s == "window"
        raise "window operator needs a hash as the last item of the array." unless stmt.last.is_a?(Hash)
        unless stmt.length == 3
          raise "window operator needs a ConceptQL statement followed by a hash as the last item of the array."
        end

        opts[:scope_opts] = (opts[:scope_opts] || {})
        opts[:scope_opts].merge!(window_opts: stmt.last.merge(cdb: cdb))
        extract_statement(stmt[1], opts)
      elsif stmt.length == 1 && stmt.first.is_a?(Array)
        extract_statement(stmt.first, opts)
      else
        [ stmt, opts ]
      end
    end

    def format(sql)
      SqlFormatters.format(sql, rdbms)
    end
  end
end
