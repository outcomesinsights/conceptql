require 'active_support/core_ext/hash'
module ConceptQL
  module Nodes
    class Node
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

      def select_it(query, specific_type = nil)
        specific_type = type if specific_type.nil? && respond_to?(:type)
        query.select(*columns(specific_type))
      end

      def types
        @types ||= determine_types
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

      def columns(local_type = nil)
        criterion_type = Sequel.expr(:criterion_type)
        if local_type
          criterion_type = Sequel.expr(local_type.to_s).cast(:text)
        end
        [:person_id___person_id,
         Sequel.expr(type_id(local_type)).as(:criterion_id),
         criterion_type.as(:criterion_type)] + date_columns(local_type)
      end

      private
      def criterion_id
        :criterion_id
      end

      def type_id(type = nil)
        return :criterion_id if type.nil?
        type = :person if type == :death
        (type.to_s + '_id').to_sym
      end

      def make_table_name(table)
        "#{table}___tab".to_sym
      end

      def date_columns(type = nil)
        return [:start_date, :end_date] unless type
        sd = start_date_column(type)
        sd = Sequel.expr(sd).cast(:date).as(:start_date) unless sd == :start_date
        ed = end_date_column(type)
        ed = Sequel.expr(ed).cast(:date).as(:end_date) unless ed == :end_date
        [sd, ed]
      end

      def start_date_column(type)
        {
          condition_occurrence: :condition_start_date,
          death: :death_date,
          drug_exposure: :drug_exposure_start_date,
          drug_cost: nil,
          payer_plan_period: :payer_plan_period_start_date,
          person: person_date_of_birth,
          procedure_occurrence: :procedure_date,
          procedure_cost: nil,
          observation: :observation_date,
          visit_occurrence: :visit_start_date
        }[type]
      end

      def end_date_column(type)
        {
          condition_occurrence: :condition_end_date,
          death: :death_date,
          drug_exposure: :drug_exposure_end_date,
          drug_cost: nil,
          payer_plan_period: :payer_plan_period_end_date,
          person: person_date_of_birth,
          procedure_occurrence: :procedure_date,
          procedure_cost: nil,
          observation: :observation_date,
          visit_occurrence: :visit_end_date
        }[type]
      end

      def person_date_of_birth
        assemble_date(:year_of_birth, :month_of_birth, :day_of_birth)
      end

      def assemble_date(*symbols)
        strings = symbols.map do |symbol|
          Sequel.function(:coalesce, Sequel.expr(symbol).cast(:text), Sequel.expr('01').cast(:text)).cast(:text)
        end
        strings = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
        Sequel.function(:date, Sequel.join(strings))
      end

      def determine_types
        if children.empty?
          if respond_to?(:type)
            [type]
          else
            raise "Node doesn't seem to specify any type"
          end
        else
          children.map(&:types).flatten.uniq
        end
      end

      def namify(name)
        require 'digest'
        digest = Digest::SHA256.hexdigest name
        ('_' + digest).to_sym
      end
    end
  end
end
