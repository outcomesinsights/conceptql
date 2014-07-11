require 'active_support/core_ext/hash'
module ConceptQL
  module Nodes
    class Node
      KNOWN_TYPES = %i(
        condition_occurrence
        death
        drug_cost
        drug_exposure
        observation
        payer_plan_period
        procedure_cost
        procedure_occurrence
        visit_occurrence
      )

      attr :values, :options
      def initialize(*args)
        args.flatten!
        if args.last.is_a?(Hash)
          @options = args.pop.symbolize_keys
        end
        @options ||= {}
        @values = args.flatten
      end

      def evaluate(db)
        select_it(query(db))
      end

      def select_it(query, select_types=types)
        query.select(*columns(select_types))
      end

      def types
        @types ||= children.map(&:types).flatten.uniq
      end

      def children
        @children ||= values.select { |v| v.is_a?(Node) }
      end

      def stream
        @stream ||= children.first
      end

      def arguments
        @arguments ||= values.reject { |v| v.is_a?(Node) }
      end

      def columns(select_types = types)
        [:person_id___person_id] + KNOWN_TYPES.map do |known_type|
          select_types.include?(known_type) ? "#{known_type}_id___#{known_type}_id".to_sym : Sequel.expr(nil).cast(:bigint).as("#{known_type}_id".to_sym)
        end + date_columns
      end

      def date_columns
        [:start_date, :end_date]
      end

      private
      def type_id(type)
        (type.to_s + '_id').to_sym
      end

      def make_table_name(table)
        "#{table}_with_dates___tab".to_sym
      end
    end
  end
end
