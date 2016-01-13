require 'psych'
require 'json'
require 'forwardable'
require_relative 'tree'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :prepped_query, :all, :count, :execute, :order

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
      @tree = opts[:tree] || Tree.new(opts)
    end

    def query
      tree.scope.with_ctes(operator.evaluate(db), db)
    end

    def sql
      (tree.scope.sql(db) << operator.sql(db)).join(";\n\n") + ';'
    end

    def annotate
      operator.annotate(db)
    end

    def optimized
      n = dup
      n.instance_variable_set(:@operator, operator.optimized)
      n
    end

    def types
      tree.root(self).types
    end

    def operator
      @operator ||= tree.root(self)
    end

    private
    attr :yaml, :tree, :db
  end
end
