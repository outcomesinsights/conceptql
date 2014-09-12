require 'zlib'
require 'active_support/core_ext/hash'
require_relative '../utils/temp_table'

module ConceptQL
  module Nodes
    class Node
      COLUMNS = [
        :person_id,
        :criterion_id,
        :criterion_type,
        :start_date,
        :end_date,
        :value_as_numeric,
        :value_as_string,
        :value_as_concept_id
      ]
      attr :values, :options, :temp_tables
      attr_accessor :tree
      def initialize(*args)
        args.flatten!
        if args.last.is_a?(Hash)
          @options = args.pop.symbolize_keys
        end
        @options ||= {}
        @values = args.flatten
        @temp_tables = {}
      end

      def evaluate(db)
        select_it(query(db))
      end

      def sql(db)
        evaluate(db).sql
      end

      def select_it(query, specific_type = nil)
        specific_type = type if specific_type.nil? && respond_to?(:type)
        query.select(*columns(query, specific_type))
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

      def columns(query, local_type = nil)
        criterion_type = :criterion_type
        if local_type
          criterion_type = Sequel.cast_string(local_type.to_s).as(:criterion_type)
        end
        columns = [:person_id,
                    type_id(local_type),
                    criterion_type]
        columns += date_columns(query, local_type)
        columns += value_columns(query)
      end

      def sql_for_temp_tables(db)
        ensure_temp_tables(db)
        children.map { |child| child.build_temp_tables(db) } + temp_tables.map { |n, tt| tt.sql(db) }
      end

      def build_temp_tables(db)
        children.each { |child| child.build_temp_tables(db) }
        ensure_temp_tables(db)
        temp_tables.each { |n, tt| tt.build(db) }
      end

      private
      # There have been a few times now that I've wanted a node to be able
      # to pass information to another node that is not directly a child
      #
      # Since tree is only object that touches each node in a statement,
      # I'm going to employ tree as a way to communicate between nodes
      #
      # This is an ugly hack, but the use case for this hack is I'm changing
      # the way `define` and `recall` nodes pass type information between
      # each other.  They used to take the type information onto the
      # database connection, but there were issues where sometimes the
      # type information was needed before we passed around the database
      # connection.
      #
      # At least this way we don't have timing issues when reading types
      attr :tree

      def criterion_id
        :criterion_id
      end

      def type_id(type = nil)
        return :criterion_id if type.nil?
        type = :person if type == :death
        Sequel.expr(make_type_id(type)).as(:criterion_id)
      end

      def make_type_id(type)
        (type.to_s + '_id').to_sym
      end

      def make_table_name(table)
        "#{table}___tab".to_sym
      end

      def value_columns(query)
        [
          numeric_value(query),
          string_value(query),
          concept_id_value(query)
        ]
      end

      def numeric_value(query)
        return :value_as_numeric if query.columns.include?(:value_as_numeric)
        Sequel.cast_numeric(nil, Float).as(:value_as_numeric)
      end

      def string_value(query)
        return :value_as_string if query.columns.include?(:value_as_string)
        Sequel.cast_string(nil).as(:value_as_string)
      end

      def concept_id_value(query)
        return :value_as_concept_id if query.columns.include?(:value_as_concept_id)
        Sequel.cast_numeric(nil).as(:value_as_concept_id)
      end

      def date_columns(query, type = nil)
        return [:start_date, :end_date] if (query.columns.include?(:start_date) && query.columns.include?(:end_date))
        return [:start_date, :end_date] unless type
        sd = start_date_column(query, type)
        sd = Sequel.expr(sd).cast(:date).as(:start_date) unless sd == :start_date
        ed = end_date_column(query, type)
        ed = Sequel.expr(ed).cast(:date).as(:end_date) unless ed == :end_date
        [sd, ed]
      end

      def start_date_column(query, type)
        {
          condition_occurrence: :condition_start_date,
          death: :death_date,
          drug_exposure: :drug_exposure_start_date,
          drug_cost: nil,
          payer_plan_period: :payer_plan_period_start_date,
          person: person_date_of_birth(query),
          procedure_occurrence: :procedure_date,
          procedure_cost: nil,
          observation: :observation_date,
          observation_period: :observation_period_start_date,
          visit_occurrence: :visit_start_date
        }[type]
      end

      def end_date_column(query, type)
        {
          condition_occurrence: :condition_end_date,
          death: :death_date,
          drug_exposure: :drug_exposure_end_date,
          drug_cost: nil,
          payer_plan_period: :payer_plan_period_end_date,
          person: person_date_of_birth(query),
          procedure_occurrence: :procedure_date,
          procedure_cost: nil,
          observation: :observation_date,
          observation_period: :observation_period_end_date,
          visit_occurrence: :visit_end_date
        }[type]
      end

      def person_date_of_birth(query)
        assemble_date(query, :year_of_birth, :month_of_birth, :day_of_birth)
      end

      def assemble_date(query, *symbols)
        strings = symbols.map do |symbol|
          Sequel.cast_string(Sequel.function(:coalesce, Sequel.cast_string(symbol), Sequel.cast_string('01')))
        end
        strings = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
        concatted_strings = Sequel.join(strings)
        case query.db.database_type
        when :oracle
          Sequel.function(:to_date, concatted_strings, 'YYYY-MM-DD')
        when :mssql
          Sequel.lit('CONVERT(DATETIME, ?)', concatted_strings)
        else
          Sequel.cast(concatted_strings, Date)
        end
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
        digest = Zlib.crc32 name
        ('_' + digest.to_s).to_sym
      end

      def ensure_temp_tables(db)
        if respond_to?(:needed_temp_tables)
          needed_temp_tables(db).each do |name, query|
            temp_table(db, name, query)
          end
        end
      end

      def temp_table(db, name, query)
        t = TempTable.new(name, query)
        return t if temp_tables[name]
        db.create_table!(name, temp: true, as: fake_row(db))
        temp_tables[name] = t
      end

      def fake_row(db)
        db
          .select(Sequel.cast(nil, Bignum).as(:person_id))
          .select_append(Sequel.cast(nil, Bignum).as(:criterion_id))
          .select_append(Sequel.cast(nil, String).as(:criterion_type))
          .select_append(Sequel.cast(nil, Date).as(:start_date))
          .select_append(Sequel.cast(nil, Date).as(:end_date))
          .select_append(Sequel.cast(nil, Bignum).as(:value_as_numeric))
          .select_append(Sequel.cast(nil, String).as(:value_as_string))
          .select_append(Sequel.cast(nil, Bignum).as(:value_as_concept_id))
      end
    end
  end
end
