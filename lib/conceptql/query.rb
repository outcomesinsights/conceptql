require 'json'
require 'open3'
require 'forwardable'
require_relative 'scope'
require_relative 'nodifier'
require_relative 'sql_formatter'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :query, :all, :count, :execute, :order

    attr :statement
    def initialize(db, statement, opts={})
      @db = db
      @statement = extract_statement(statement)
      opts = opts.dup
      opts[:algorithm_fetcher] ||= proc do |alg|
        statement, description = db[:concepts].where(concept_id: alg).get([:statement, :label])
        statement = JSON.parse(statement) if statement.is_a?(String)
        [statement, description]
      end
      @nodifier = opts[:nodifier] || Nodifier.new({ database_type: db.database_type}.merge(opts))
    end

    def query
      nodifier.scope.with_ctes(operator.evaluate(db), db)
    end

    def sql
      SqlFormatter.new.format(query.sql)
    rescue
      puts $!.message
      puts $!.backtrace.join("\n")
      return "SQL unavailable for this statement"
    end

    def annotate(opts = {})
      nodifier.scope.with_temps(operator, db) unless opts[:skip_count]
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
      operator.domains
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

    def code_list(db)
      operator.code_list(db)
    end

    private
    attr :db, :nodifier


    def extract_statement(stmt)
      if stmt.is_a?(Array) && stmt.length == 1 && stmt.first.is_a?(Array)
        stmt.first
      else
        stmt
      end
    end
  end
end
