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

    def query
      build_query(db)
    end

    def execute
      build_query(db).each(&:all)
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
