require 'json'
require 'forwardable'
require_relative 'scope'
require_relative 'nodifier'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :all, :count, :execute, :order

    attr :statement
    def initialize(db, statement, opts={})
      @db = db
      @statement = statement
      opts = opts.dup
      opts[:algorithm_fetcher] ||= proc do |alg|
        statement, description = db[:concepts].where(concept_id: alg).get([:statement, :label])
        statement = JSON.parse(statement) if statement.is_a?(String)
        [statement, description]
      end
      @nodifier = opts[:nodifier] || Nodifier.new(opts)
    end

    def query
      nodifier.scope.with_ctes(operator.evaluate(db), db)
    end

    def sql
      operator.sql(db)
    end

    def annotate
      operator.annotate(db)
    end
    
    def scope_annotate
      annotate
      nodifier.scope.annotation
    end

    def optimized
      n = dup
      n.instance_variable_set(:@operator, operator.optimized)
      n
    end

    def types
      operator.types
    end

    def operator
      @operator ||= if statement.is_a?(Array)
        nodifier.create(*statement)
      else
        Operators::Invalid.new(nodifier, errors: ["invalid root operator"])
      end
    end

    private
    attr :db, :nodifier
  end
end
