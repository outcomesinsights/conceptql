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
      def types
        [type]
      end

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
        uncastable_types = stream.types - castables
        to_me_types = stream.types & these_point_at_me
        from_me_types = stream.types & i_point_at

        destination_table = make_table_name(my_type)
        casting_query = db.from(destination_table)
        wheres = []

        unless uncastable_types.empty?
          # We have a situation where one or more of the incoming streams
          # isn't castable so we'll just return all rows for
          # all people in each uncastable stream
          uncastable_person_ids = db.from(stream_query)
            .where(criterion_type: uncastable_types.map(&:to_s))
            .select_group(:person_id)
          wheres << Sequel.expr(person_id: uncastable_person_ids)
        end

        destination_type_id = type_id(my_type)

        unless to_me_types.empty?
          # For each castable type in the stream, setup a query that
          # casts each type to a set of IDs, union those IDs and fetch
          # them from the source table
          castable_type_query = to_me_types.map do |source_type|
            source_ids = db.from(stream_query)
              .where(criterion_type: source_type.to_s)
              .select_group(:criterion_id)
            source_table = make_table_name(source_type)
            source_type_id = type_id(source_type)

            db.from(source_table)
              .where(source_type_id => source_ids)
              .select(destination_type_id)
          end.inject do |union_query, q|
            union_query.union(q)
          end
          wheres << Sequel.expr(destination_type_id => castable_type_query)
        end

        unless from_me_types.empty?
          from_me_types.each do |from_me_type|
            fk_type_id = type_id(from_me_type)
            wheres << Sequel.expr(fk_type_id => db.from(stream_query).where(criterion_type: from_me_type.to_s).select_group(:criterion_id))
          end
        end

        casting_query.where(wheres.inject(&:|))
      end
    end
  end
end
