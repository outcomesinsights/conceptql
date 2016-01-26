require 'zlib'
require_relative '../behaviors/metadatable'
require 'facets/array/extract_options'
require 'facets/hash/deep_rekey'
require 'forwardable'

module ConceptQL
  module Operators
    OPERATORS = {:omopv4=>{}}.freeze

    def self.operators
      OPERATORS
    end

    class Operator
      extend Forwardable
      extend Metadatable
      COLUMNS = [
        :person_id,
        :criterion_id,
        :criterion_type,
        :start_date,
        :end_date,
        :value_as_number,
        :value_as_string,
        :value_as_concept_id,
        :units_source_value,
        :source_value
      ]

      attr :values, :options, :arguments, :upstreams

      option :label, type: :string

      def self.register(file, *data_models)
        data_models.each do |dm|
          OPERATORS[dm][File.basename(file).sub(/\.rb\z/, '')] = self
        end
      end

      def initialize(*args)
        set_values(*args)
      end

      def values=(*args)
        set_values(*args)
      end

      def set_values(*args)
        @options = args.extract_options!.deep_rekey
        @upstreams, @arguments = args.partition { |arg| arg.is_a?(Operator) }
        @values = args
      end

      def annotate(db)
        res = [self.class.just_class_name.underscore] + annotate_values(db)

        metadata = {:annotation=>{}}
        if name = self.class.preferred_name
          metadata[:name] = name
        end

        annotation = metadata[:annotation]
        evaluate(db)
          .from_self
          .select_group(:criterion_type)
          .select_append{count{}.*.as(:rows)}
          .select_append{count(:person_id).distinct.as(:n)}
          .each do |h|
            puts h
            annotation[h.delete(:criterion_type).to_sym] = h
        end
        types.each do |type|
          annotation[type] ||= {:rows=>0, :n=>0}
        end
        if res.last.is_a?(Hash)
          res.last.merge!(metadata)
        else
          res << metadata
        end

        res
      end

      def dup_values(args)
        self.class.new(*args)
      end

      def scope=(scope)
        @scope = scope
        scope.add_operator(self)
      end

      def evaluate(db)
        select_it(query(db))
      end

      def sql(db)
        evaluate(db).sql
      end

      def optimized
        dup_values(values.map{|x| x.is_a?(Operator) ? x.optimized : x})
      end

      def unionable?(other)
        false
      end

      def select_it(query, specific_type = nil)
        specific_type = type if specific_type.nil? && respond_to?(:type)
        q = query.select(*columns(query, specific_type))
        if scope && scope.person_ids && upstreams.empty?
          q = q.where(person_id: scope.person_ids).from_self
        end
        q
      end

      def types
        @types ||= determine_types
      end

      def stream
        @stream ||= upstreams.first
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
        columns += value_columns(query, local_type)
      end

      def label
        options[:label]
      end

      private
      attr :scope

      def annotate_values(db)
        (upstreams.map { |op| op.annotate(db) } + arguments).push(options)
      end

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

      def value_columns(query, type)
        [
          numeric_value(query),
          string_value(query),
          concept_id_value(query),
          units_source_value(query),
          source_value(query, type)
        ]
      end

      def numeric_value(query)
        return :value_as_number if query.columns.include?(:value_as_number)
        Sequel.cast_numeric(nil, Float).as(:value_as_number)
      end

      def string_value(query)
        return :value_as_string if query.columns.include?(:value_as_string)
        Sequel.cast_string(nil).as(:value_as_string)
      end

      def concept_id_value(query)
        return :value_as_concept_id if query.columns.include?(:value_as_concept_id)
        Sequel.cast_numeric(nil).as(:value_as_concept_id)
      end

      def units_source_value(query)
        return :units_source_value if query.columns.include?(:units_source_value)
        Sequel.cast_string(nil).as(:units_source_value)
      end

      def source_value(query, type)
        return :source_value if query.columns.include?(:source_value)
        Sequel.cast_string(source_value_column(query, type)).as(:source_value)
      end

      def date_columns(query, type = nil)
        return [:start_date, :end_date] if (query.columns.include?(:start_date) && query.columns.include?(:end_date))
        return [:start_date, :end_date] unless type

        date_klass = Date
        if query.db.database_type == :impala
          date_klass = DateTime
        end

        sd = start_date_column(query, type)
        sd = Sequel.cast(Sequel.expr(sd), date_klass).as(:start_date) unless sd == :start_date
        ed = end_date_column(query, type)
        ed = Sequel.cast(Sequel.function(:coalesce, Sequel.expr(ed), start_date_column(query, type)), date_klass).as(:end_date) unless ed == :end_date
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

      def source_value_column(query, type)
        {
          condition_occurrence: :condition_source_value,
          death: :cause_of_death_source_value,
          drug_exposure: :drug_source_value,
          drug_cost: nil,
          payer_plan_period: :payer_plan_period_source_value,
          person: :person_source_value,
          procedure_occurrence: :procedure_source_value,
          procedure_cost: nil,
          observation: :observation_source_value,
          observation_period: nil,
          visit_occurrence: :place_of_service_source_value
        }[type]
      end

      def person_date_of_birth(query)
        assemble_date(query, :year_of_birth, :month_of_birth, :day_of_birth)
      end

      def assemble_date(query, *symbols)
        strings = symbols.map do |symbol|
          sub = '2000'
          col = Sequel.cast_string(symbol)
          if symbol != :year_of_birth
            sub = '01'
            col = Sequel.function(:lpad, col, 2, '0')
          end
          Sequel.function(:coalesce, col, Sequel.expr(sub))
        end

        strings_with_dashes = strings.zip(['-'] * (symbols.length - 1)).flatten.compact
        concatted_strings = Sequel.join(strings_with_dashes)

	date = concatted_strings
	if query.db.database_type == :impala
          date = Sequel.cast(Sequel.function(:concat_ws, '-', *strings), DateTime)
        end
        cast_date(query.db, date)
      end

def  cast_date(db, date)
        case db.database_type
        when :oracle
          Sequel.function(:to_date, date, 'YYYY-MM-DD')
        when :mssql
          Sequel.lit('CONVERT(DATETIME, ?)', date)
        when :impala
          Sequel.cast(Sequel.cast(date Sequel.function(:concat_ws, '-', *strings), DateTime), DateTime)
        else
          Sequel.cast(date, Date)
        end
end

      def determine_types
        if upstreams.empty?
          if respond_to?(:type)
            [type]
          else
            raise "Operator doesn't seem to specify any type"
          end
        else
          upstreams.map(&:types).flatten.uniq
        end
      end
    end
  end
end

# Require all operator subclasses eagerly
Dir.new(File.dirname(__FILE__)).
  entries.
  each{|filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
