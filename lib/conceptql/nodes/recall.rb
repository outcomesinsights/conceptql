require_relative 'pass_thru'

module ConceptQL
  module Nodes
    # Mimics using a variable that has been set via "define" node
    #
    # The idea is that a concept might be very complex and it helps to break
    # that complex concept into a set of sub-concepts to better understand it.
    #
    # This node will look for a sub-concept that has been created through the
    # "define" node and will fetch the results cached in the corresponding table
    class Recall < Node
      # Behind the scenes we simply fetch all rows from the temp table that
      # corresponds to the name fed to "recall"
      #
      # We also set the @types variable by pulling the type information out
      # of the hash piggybacking on the database connection.
      #
      # TODO: This might be an issue since we might need the type information
      # before we call #query.  Probably time to reevaluate how we're caching
      # the type information.
      def query(db)
        table_name = namify(arguments.first)
        @types = db.types[table_name]
        db.from(table_name)
      end

      def types
        @types
      end
    end
  end
end

