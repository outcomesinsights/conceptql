require_relative 'casting_operator'

module ConceptQL
  module Operators
    class ObservationPeriod < CastingOperator
      include ConceptQL::Behaviors::Windowable

      register __FILE__

      desc 'Generates all observation_period records, or, if fed a stream, fetches all observation_period records for the people represented in the incoming result set.'
      domains :observation_period
      allows_one_upstream
      deprecated replaced_by: "information_periods"

      def my_domain
        :observation_period
      end

      def source_table
        dm.table_by_domain(:observation_period)
      end

      def i_point_at
        []
      end

      def these_point_at_me
        # I could list ALL the domains we use, but the default behavior of casting,
        # when there is no explicit casting defined, is to convert everything to
        # person IDs
        #
        # So by defining no known castable relationships in this operator, all
        # domains will be converted to person
        []
      end
    end
  end
end

