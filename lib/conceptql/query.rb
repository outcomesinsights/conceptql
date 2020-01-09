require 'json'
require 'open3'
require 'forwardable'
require_relative 'scope'
require_relative 'nodifier'
require_relative 'sql_formatters'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :query, :all, :count, :execute, :order, :profile
    def_delegators :cdb, :db, :rdbms, :dm
    def_delegators :db, :profile_for

    attr :statement
    def initialize(cdb, statement, opts={})
      @cdb = cdb
      @statement, opts = extract_statement(statement, opts.dup)
      opts[:algorithm_fetcher] ||= proc do |alg|
        statement, description = db[:concepts].where(concept_id: alg).get([:statement, :label])
        statement = JSON.parse(statement) if statement.is_a?(String)
        [statement, description]
      end
      nodifier_opts = {
        database_type: db ? db.database_type : nil,
        dm: dm,
        rdbms: rdbms
      }
      @nodifier = opts[:nodifier] || Nodifier.new(nodifier_opts.merge(opts))
    end

    def analyze
      query(explain: true, analyze: true).analyze
    end

    def query(opts = {})
      nodifier.scope.with_ctes(operator, db, opts)#.tap { |o| pp o.opts ; binding.pry }
    end

    def query_cols(opts = {})
      cols = operator.dynamic_columns
      if opts[:cast]
        cols = query_cols.each_with_object({}) do |column, h|
          h[column] = operator.cast_column(column)
        end
      end
      cols
    end

    def sql(*args)
      sql_statements(*args).values.join(";\n")
    end

    def sql_statements(*args)
      stmts = query.sql_statements

      if args.include?(:create_tables)
        sql = stmts.delete(:query)
        stmts = stmts.map do |name, sql|
          [name, db.send(:create_table_as_sql, name, sql, {})]
        end.push([:query, sql])
      end

      if args.include?(:formatted)
        stmts = stmts.map do |name, sql|
          [name, format(sql)]
        end
      end
      Hash[stmts]
      # TODO: throw a reasonable error here
    rescue
      #puts $!.message
      #puts $!.backtrace.join("\n")
      return { query: "SQL unavailable for this statement\n#{$!.message}\n#{$!.backtrace.join("\n")}" }
      #raise
    end

    def annotate(opts = {})
      operator.annotate(db, opts)
    end

    def scope_annotate(opts = {})
      annotate(opts)
      nodifier.scope.annotation
    end

    def optimized
      n = dup
      n.instance_variable_set(:@operator, operator.optimized)
      n
    end

    def domains
      operator.domains(db)
    end

    def operator
      @operator ||= if statement.is_a?(Array)
        if statement.first.is_a?(Array)
          Operators::Invalid.new(nodifier, "invalid", errors: [["incomplete statement"]])
        else
          nodifier.create(*statement)
        end
      else
        Operators::Invalid.new(nodifier, "invalid", errors: [["invalid root operator", statement.inspect]])
      end
    end

    def code_list(ignored_db = nil)
      operator.code_list(db).uniq
    end

    def drop_temp_tables(opts = {})
      query.drop_temp_tables(opts)
    end

    def include_column?(column)
      nodifier.scope.query_columns.include?(column)
    end

    private
    attr :cdb, :nodifier

    def extract_statement(stmt, opts)
      if !stmt.is_a?(Array)
        raise "Improper ConceptQL statement: Expected an Array, got a #{stmt.class}"
      elsif stmt.first.to_s == "window"
        raise "window operator needs a hash as the last item of the array." unless stmt.last.is_a?(Hash)
        raise "window operator needs a ConceptQL statement followed by a hash as the last item of the array." unless stmt.length == 3
        opts[:scope_opts] = (opts[:scope_opts] || {}).dup
        opts[:scope_opts].merge!(window_opts: stmt.last.merge(cdb: cdb))
        extract_statement(stmt[1], opts)
      elsif stmt.length == 1 && stmt.first.is_a?(Array)
        extract_statement(stmt.first, opts)
      else
        [[:projection, stmt], opts]
      end
    end

    def format(sql)
      SqlFormatters.format(sql, rdbms)
    end
  end
end
