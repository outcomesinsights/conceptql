require_relative 'node'
require_relative '../query'

module ConceptQL
  module Nodes
    class Concept < Node
      desc 'Given the UUID of another ConceptQL statement, returns the results of that statement.'
      attr :cql_query
      def query(db)
        set_cql_query(db)
        db.from(cql_query.query.from_self)
      end

      def children
        @children ||= cql_query.nodes
      end

      def graph_prep(db)
        set_cql_query(db)
        puts statement.inspect
        @arguments = [description(db)]
      end

      def print_prep(db)
        set_cql_query(db)
      end

      def ensure_temp_tables(db)
        set_cql_query(db)
        super
      end

      def build_temp_tables(db)
        set_cql_query(db)
        super
      end

      private

      def set_cql_query(db)
        @cql_query ||= begin
          set_statement(db)
          Query.new(db, statement)
        end
      end

      def statement
        raise "Statement is nil!" unless @statement
        @statement
      end

      def set_statement(db)
        @statement ||= get_statement(db)
      end

      def get_statement(db)
        concept = db[:concepts].where(concept_id: arguments.first).limit(1)
        statement = concept.select_map(:statement).first.tap { |f| ConceptQL.logger.debug f.inspect }
        statement = JSON.parse(statement) if statement.is_a?(String)
        statement
      end

      def description(db)
        @description ||= db[:concepts].where(concept_id: arguments.first).select_map(:label).first
      end
    end
  end
end


