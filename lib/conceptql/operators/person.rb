require_relative 'casting_operator'

module ConceptQL
  module Operators
    class Person < CastingOperator
      register __FILE__, :omopv4

      desc 'Returns all people in the database, or if given a upstream, converts all results to the set of patients contained in those results.'
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
