require_relative 'operator'

module ConceptQL
  module Nodes
    class PassThru < Operator
      def types
        upstreams.map(&:types).flatten.uniq
      end
    end
  end
end
