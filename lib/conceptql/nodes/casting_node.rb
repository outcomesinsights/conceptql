require_relative 'node'

module ConceptQL
  module Nodes
    # Parent class of all casting nodes
    #
    # Subclasses must implement the following methods:
    # - my_type
    # - i_point_at
    # - these_point_at_me
    #
    # i_point_at returns a list of types for which the node's table of origin
    # has foreign_keys pointing to another table, e.g.:
    # procedure_occurrence has an FK to visit_occurrence, so we'd put
    # :visit_occurrence in the i_point_at array
    #
    # these_point_at_me is a list of types for which that type's table
    # of origin has a FK  pointing to the current node's
    # table of origin, e.g.:
    # procedure_cost has an FK to procedure_occurrence so we'd
    # put :procedure_cost in procedure_occurrence's these_point_at_me array
    #
    # Also, if a casting node is passed no streams, it will return all the
    # rows in its table as results.
    class CastingNode < Node
      def type
        my_type
      end

      def castables
        (i_point_at + these_point_at_me)
      end

      def query(db)
        return db.from(make_table_name(my_type)) if stream.nil?
        base_query(db, stream.evaluate(db))
      end

      private

      def base_query(db, stream_query)
        if (stream.types & castables).length < stream.types.length
          # We have a situation where one of the incoming streams
          # isn't castable so we'll just return all rows for
          # all people
          db.from(make_table_name(my_type))
            .where(person_id: db.from(stream_query).select_group(:person_id))
        else
          # Every type in the stream is castable, so let's setup a query that
          # casts each type to a set of IDs, union those IDs and fetch
          # them from the source table
          my_ids = stream.types.map do |type|
            cast_type(db, type, stream_query)
          end.inject do |union_query, query|
            union_query.union(query)
          end

          db.from(make_table_name(my_type))
            .where(type_id(my_type) => my_ids)
        end
      end

      def cast_type(db, type, stream_query)
        query = if i_point_at.include?(type)
          db.from(make_table_name(my_type))
            .where(type_id(type) => db.from(stream_query.select_group(type_id(type))))
        else
          db.from(make_table_name(type))
            .where(type_id(type) => db.from(stream_query.select_group(type_id(type))))
        end
        query.select(type_id(my_type))
      end
    end
  end
end
