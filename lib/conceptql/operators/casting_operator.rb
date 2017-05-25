require_relative 'operator'

module ConceptQL
  module Operators
    # Parent class of all casting operators
    #
    # Subclasses must implement the following methods:
    # - my_domain
    # - i_point_at
    # - these_point_at_me
    #
    # i_point_at returns a list of domains for which the operator's table of origin
    # has foreign_keys pointing to another table, e.g.:
    # procedure_occurrence has an FK to visit_occurrence, so we'd put
    # :visit_occurrence in the i_point_at array
    #
    # these_point_at_me is a list of domains for which that domain's table
    # of origin has a FK  pointing to the current operator's
    # table of origin, e.g.:
    # procedure_cost has an FK to procedure_occurrence so we'd
    # put :procedure_cost in procedure_occurrence's these_point_at_me array
    #
    # Also, if a casting operator is passed no streams, it will return all the
    # rows in its table as results.
    class CastingOperator < Operator
      category "Get Related Data"
      basic_type :cast
      validate_at_most_one_upstream
      validate_no_arguments

      def domains(db)
        [domain]
      end

      def domain
        my_domain
      end

      def castables
        (i_point_at + these_point_at_me)
      end

      def query_cols
        dm.table_columns(make_table_name(table))
      end

      def query(db)
        return db.from(make_table_name(source_table)) if stream.nil?
        base_query(db, stream.evaluate(db))
      end

      def table
        source_table
      end

      private

      def base_query(db, stream_query)
        uncastable_domains = stream.domains(db) - castables
        to_me_domains = stream.domains(db) & these_point_at_me
        from_me_domains = stream.domains(db) & i_point_at

        destination_table = make_table_name(source_table)
        casting_query = db.from(destination_table)
        wheres = []

        unless uncastable_domains.empty?
          # We have a situation where one or more of the incoming streams
          # isn't castable so we'll just return all rows for
          # all people in each uncastable stream
          uncastable_person_ids = db.from(stream_query)
            .where(criterion_domain: uncastable_domains.map(&:to_s))
            .select_group(:person_id)
          wheres << Sequel.expr(dm.person_id => uncastable_person_ids)
        end

        destination_domain_id = dm.make_table_id(source_table)

        unless to_me_domains.empty?
          # For each castable domain in the stream, setup a query that
          # casts each domain to a set of IDs, union those IDs and fetch
          # them from the source table
          castable_domain_query = to_me_domains.map do |source_domain|
            source_ids = db.from(stream_query)
              .where(criterion_domain: source_domain.to_s)
              .select_group(:criterion_id)
            source_table = make_table_name(source_table)
            source_domain_id = dm.make_table_id(source_table)

            db.from(source_table)
              .where(source_domain_id => source_ids)
              .select(destination_domain_id)
          end.inject do |union_query, q|
            union_query.union(q, all: true)
          end
          wheres << Sequel.expr(destination_domain_id => castable_domain_query)
        end

        unless from_me_domains.empty?
          from_me_domains.each do |from_me_domain|
            fk_domain_id = make_table_id(from_me_domain)
            wheres << Sequel.expr(fk_domain_id => db.from(stream_query).where(criterion_domain: from_me_domain.to_s).select_group(:criterion_id))
          end
        end

        casting_query.where(wheres.inject(&:|))
      end
    end
  end
end
