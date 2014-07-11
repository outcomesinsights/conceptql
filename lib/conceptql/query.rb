require 'psych'
require_relative 'tree'
require_relative 'view_maker'

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
      ensure_views
      build_query(db).all
    end

    def types
      tree.root(self).types
    end

    private
    attr :yaml, :tree, :db

    def build_query(db)
      tree.root(self).evaluate(db)
    end

    def ensure_views
      return if db.views.include?(:person_with_dates)
      ViewMaker.make_views(db)
    end
  end
end
