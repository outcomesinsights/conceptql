require_relative 'casting_operator'

module ConceptQL
  module Operators
    class Person < CastingOperator
      register __FILE__, :omopv4

      desc 'Generates all person records, or, if fed a stream, fetches all person records for the people represented in the incoming result set.'
      allows_one_upstream
      domains :person

      def my_domain
        :person
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
