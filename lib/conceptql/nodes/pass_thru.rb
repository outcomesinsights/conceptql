require_relative 'node'

module ConceptQL
  module Nodes
    class PassThru < Node
      def types
        children.map(&:types).flatten.uniq
      end
    end
  end
end
