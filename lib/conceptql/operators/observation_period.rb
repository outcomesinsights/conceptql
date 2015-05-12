require_relative 'casting_node'

module ConceptQL
  module Operators
    class ObservationPeriod < CastingNode
      desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming result set.'
      types :observation_period
      allows_one_upstream

      def my_type
        :observation_period
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

