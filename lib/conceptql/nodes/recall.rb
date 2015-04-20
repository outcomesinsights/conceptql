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
      desc <<-EOF
Recalls a set of named results that were previously stored using the Define operator.
Must be surrounded by the same Let operator as surrounds the corresponding Define operator.
      EOF
      argument :name, type: :string
      category 'Assignment'

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
        # We're going to call evaluate on definition to ensure the definition
        # has been created.  We were running into odd timing issues when
        # drawing graphs where the recall node was being drawn before definition
        # was drawn.
        db.from(table_name)
      end

      def columns(query, local_type)
        COLUMNS
      end

      def types
        definition.types
      end

      private
      def table_name
        @table_name ||= namify(description)
      end

      def definition
        tree.defined[table_name]
      end

      def description
        arguments.first
      end
    end
  end
end

