require_relative 'casting_node'

module ConceptQL
  module Nodes
    class Person < CastingNode
      desc 'Returns all people in the database, or if given a upstream, converts all results to the set of patients contained in those results.'
      allows_one_upstream
      types :person

      def my_type
        :person
      end

      def i_point_at
        []
      end

      def these_point_at_me
        # I could list ALL the types we use, but the default behavior of casting,
        # when there is no explicit casting defined, is to convert everything to
        # person IDs
        #
        # So by defining no known castable relationships in this node, all
        # types will be converted to person
        []
      end
    end
  end
end
