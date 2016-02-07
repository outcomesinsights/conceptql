require_relative 'casting_operator'

module ConceptQL
  module Operators
    class ObservationPeriod < CastingOperator
      register __FILE__, :omopv4

      desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming result set.'
      types :observation_period
      allows_one_upstream
      validate_at_most_one_upstream
      validate_no_arguments

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
        # So by defining no known castable relationships in this operator, all
        # types will be converted to person
        []
      end
    end
  end
end

