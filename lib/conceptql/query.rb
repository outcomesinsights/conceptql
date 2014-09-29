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

    def queries
      build_query(db)
    end

    def query
      queries.last
    end

    def sql
      temp_tables = nodes.flat_map { |n| n.sql_for_temp_tables(db) }
      sql = (temp_tables << nodes.last.evaluate(db).sql).join(";\n") + ';'
      sql
    end

    def types
      tree.root(self).last.types
    end

    private
    attr :yaml, :tree, :db

    def build_query(db)
      nodes.map { |n| n.evaluate(db) }.each { |q| q.prep_proc = prep_proc }
    end

    def nodes
      @nodes ||= tree.root(self)
    end

    def prep_proc
      @prep_proc = Proc.new { puts 'PREPPING'; nodes.each { |n| n.build_temp_tables(db) } }
    end

    def prepped_query
#      @prepped_query ||= PreppedQuery.new(query, Proc.new { puts 'PREPPING'; nodes.each { |n| n.build_temp_tables(db) } })
      query
    end
  end
end
