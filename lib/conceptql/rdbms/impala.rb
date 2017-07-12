require_relative "generic"

module ConceptQL
  module Rdbms
    class Impala < Generic
      def cast_date(date)
        Sequel.cast(date, DateTime)
      end

      # Impala is teh dumb in that it won't allow columns with constants to
      # be part of the partition of a window function.
      #
      # Concatting other constants didn't seem to fix the problem
      #
      # Since we're partitioning by person_id at all times, it seems like a
      # safe bet that we can append the person_id to any constant, making it
      # no longer a constant, but still a viable column for partitioning
      def partition_fix(column)
        Sequel.expr(column) + '_' + Sequel.cast_string(:person_id)
      end
    end
  end
end
