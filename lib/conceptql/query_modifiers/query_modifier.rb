module ConceptQL
  module QueryModifiers
    class QueryModifier
      attr :query, :op, :source_table, :dm

      def initialize(query, op, table, dm)
        @query = query
        @op = op
        @source_table = table
        @dm = dm
      end

      def modified_query
        raise NotImplementedError
      end
    end
  end
end
