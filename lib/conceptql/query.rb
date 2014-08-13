require 'psych'
require_relative 'tree'

module ConceptQL
  class Query
    attr :statement
    def initialize(db, statement, tree = Tree.new)
      @db = db
      @statement = statement
      @tree = tree
    end

    def queries
      build_query(db)
    end

    def query
      queries.last
    end

    def sql
      query.map(&:sql).join('\n')
    end

    def execute
      query.all
    end

    def types
      tree.root(self).types
    end

    private
    attr :yaml, :tree, :db

    def build_query(db)
      tree.root(self).map { |n| n.evaluate(db) }
    end
  end
end
