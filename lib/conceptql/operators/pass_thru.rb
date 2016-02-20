require_relative 'operator'

module ConceptQL
  module Operators
    class PassThru < Operator
      register __FILE__, :omopv4

      def types
        types = upstreams.map(&:types).flatten.uniq
        types.empty? ? [:invalid] : types
      end

      def query_cols
        upstreams.first.query_cols
      end
    end
  end
end
