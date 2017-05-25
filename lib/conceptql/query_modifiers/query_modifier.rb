module ConceptQL
  module QueryModifiers
    class QueryModifier
      attr :query, :op

      def initialize(query, op)
        @query = query
        @op = op
      end

      def modified_query
        raise NotImplementedError
      end
    end
  end
end
