require_relative 'node'
require_relative '../tree'

module ConceptQL
  module Nodes
    class Concept < Node
      attr :statement
      def query(db)
        set_statement(db)
        stream.evaluate(db)
      end

      def children
        @children ||= [ Tree.new.root(self) ]
      end

      def graph_prep(db)
        set_statement(db)
        @arguments = [description(db)]
      end

      private
      def set_statement(db)
        @statement ||= db[:concepts].where(concept_id: arguments.first).select_map(:statement).first.tap { |f| ConceptQL.logger.debug f.inspect }.to_hash
      end

      def description(db)
        @description ||= db[:concepts].where(concept_id: arguments.first).select_map(:label).first
      end

      def db
        tree.db
      end
    end
  end
end


