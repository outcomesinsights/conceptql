require_relative 'operator'

module ConceptQL
  module Operators
    class PassThru < Operator
      register __FILE__, :omopv4

      def types
        upstreams.map(&:types).flatten.uniq
      end
    end
  end
end
