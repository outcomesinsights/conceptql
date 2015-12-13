require 'psych'
require 'forwardable'
require_relative 'behaviors/preppable'
require_relative 'tree'

module ConceptQL
  class Query
    extend Forwardable
    def_delegators :prepped_query, :all, :count, :execute, :order

    class Projection
      attr :query

      def inspect
        "<#ConceptQL::Query::Projection#{'(cached)' if @cached} #{query.sql}>"
      end

      def all
        if @cached
          @all
        else
          query.all
        end
      end

      def initialize(query, opts={})
        @query = query
        if @cached = opts.fetch(:cached, true)
          @projection_ids = {}
          @all = query.all do |h|
            (@projection_ids[h[:criterion_type]] ||= []) << h[:criterion_id]
          end
        end
      end

      def project(type, *columns)
        ds = query.db.from(type).select(*columns)
        id_column = Sequel.identifier("#{type}_id")
        if @cached
          if ids = @projection_ids[type.to_s]
            ds.where(id_column=>@projection_ids[type.to_s])
          else
            ds.where(false)
          end
        else
          ds.where(id_column=>query.select(:criterion_id).where(:criterion_type=>type.to_s))
        end
      end
    end

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

    def projection(opts={})
      Projection.new(query, opts)
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
