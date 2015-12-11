require 'psych'
require 'forwardable'
require_relative 'behaviors/preppable'
require_relative 'tree'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :prepped_query, :all, :count, :execute, :order

    attr :statement
    def initialize(db, statement, tree = Tree.new)
      @db = db
      @db.extend_datasets(ConceptQL::Behaviors::Preppable)
      @statement = statement
      @tree = tree
    end

    def query
      build_query(db)
    end

    def sql
      (tree.scope.sql(db) << operator.sql(db)).join(";\n\n") + ';'
    end

    def types
      tree.root(self).types
    end

    def operator
      @operator ||= tree.root(self)
    end

    private
    attr :yaml, :tree, :db

    def build_query(db)
      operator.evaluate(db).tap { |q| q.prep_proc = prep_proc }
    end

    def prep_proc
      @prep_proc = Proc.new { puts 'PREPPING'; tree.scope.prep(db) }
    end

    def prepped_query
      query
    end
  end
end
