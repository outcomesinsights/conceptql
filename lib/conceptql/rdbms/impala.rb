require_relative "generic"

module ConceptQL
  module Rdbms
    class Impala < Generic
      def cast_date(date)
        Sequel.cast(date, DateTime)
      end
    end
  end
end

