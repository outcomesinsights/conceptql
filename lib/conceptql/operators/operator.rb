require 'zlib'
require_relative '../behaviors/metadatable'
require 'facets/array/extract_options'
require 'facets/hash/deep_rekey'
require 'forwardable'

module ConceptQL
  module Operators
    OPERATORS = {:omopv4=>{}}.freeze

    SELECTED_COLUMNS = [:person_id, :criterion_id, :criterion_type, :start_date, :end_date, :value_as_number, :value_as_string, :value_as_concept_id, :units_source_value, :source_value]

    TABLE_COLUMNS = {
      :care_site=>[:care_site_id, :location_id, :organization_id, :place_of_service_concept_id, :care_site_source_value, :place_of_service_source_value],
      :cohort=>[:cohort_id, :cohort_concept_id, :cohort_start_date, :cohort_end_date, :subject_id, :stop_reason],
      :concept=>[:concept_id, :concept_name, :concept_level, :concept_class, :vocabulary_id, :concept_code, :valid_start_date, :valid_end_date, :invalid_reason],
      :concept_ancestor=>[:ancestor_concept_id, :descendant_concept_id, :min_levels_of_separation, :max_levels_of_separation],
      :concept_relationship=>[:concept_id_1, :concept_id_2, :relationship_id, :valid_start_date, :valid_end_date, :invalid_reason],
      :concept_synonym=>[:concept_synonym_id, :concept_id, :concept_synonym_name],
      :condition_era=>[:condition_era_id, :person_id, :condition_concept_id, :condition_era_start_date, :condition_era_end_date, :condition_type_concept_id, :condition_occurrence_count],
      :condition_occurrence=>[:condition_occurrence_id, :person_id, :condition_concept_id, :condition_start_date, :condition_end_date, :condition_type_concept_id, :stop_reason, :associated_provider_id, :visit_occurrence_id, :condition_source_value],
      :death=>[:person_id, :death_date, :death_type_concept_id, :cause_of_death_concept_id, :cause_of_death_source_value],
      :drug_approval=>[:ingredient_concept_id, :approval_date, :approved_by],
      :drug_cost=>[:drug_cost_id, :drug_exposure_id, :paid_copay, :paid_coinsurance, :paid_toward_deductible, :paid_by_payer, :paid_by_coordination_benefits, :total_out_of_pocket, :total_paid, :ingredient_cost, :dispensing_fee, :average_wholesale_price, :payer_plan_period_id],
      :drug_era=>[:drug_era_id, :person_id, :drug_concept_id, :drug_era_start_date, :drug_era_end_date, :drug_type_concept_id, :drug_exposure_count],
      :drug_exposure=>[:drug_exposure_id, :person_id, :drug_concept_id, :drug_exposure_start_date, :drug_exposure_end_date, :drug_type_concept_id, :stop_reason, :refills, :quantity, :days_supply, :sig, :prescribing_provider_id, :visit_occurrence_id, :relevant_condition_concept_id, :drug_source_value],
      :drug_strength=>[:drug_concept_id, :ingredient_concept_id, :amount_value, :amount_unit, :concentration_value, :concentration_enum_unit, :concentration_denom_unit, :valid_start_date, :valid_end_date, :invalid_reason],
      :location=>[:location_id, :address_1, :address_2, :city, :state, :zip, :county, :location_source_value],
      :observation=>[:observation_id, :person_id, :observation_concept_id, :observation_date, :observation_time, :value_as_number, :value_as_string, :value_as_concept_id, :unit_concept_id, :range_low, :range_high, :observation_type_concept_id, :associated_provider_id, :visit_occurrence_id, :relevant_condition_concept_id, :observation_source_value, :units_source_value],
      :observation_period=>[:observation_period_id, :person_id, :observation_period_start_date, :observation_period_end_date, :prev_ds_period_end_date],
      :organization=>[:organization_id, :place_of_service_concept_id, :location_id, :organization_source_value, :place_of_service_source_value],
      :payer_plan_period=>[:payer_plan_period_id, :person_id, :payer_plan_period_start_date, :payer_plan_period_end_date, :payer_source_value, :plan_source_value, :family_source_value, :prev_ds_period_end_date],
      :person=>[:person_id, :gender_concept_id, :year_of_birth, :month_of_birth, :day_of_birth, :race_concept_id, :ethnicity_concept_id, :location_id, :provider_id, :care_site_id, :person_source_value, :gender_source_value, :race_source_value, :ethnicity_source_value],
      :procedure_cost=>[:procedure_cost_id, :procedure_occurrence_id, :paid_copay, :paid_coinsurance, :paid_toward_deductible, :paid_by_payer, :paid_by_coordination_benefits, :total_out_of_pocket, :total_paid, :disease_class_concept_id, :revenue_code_concept_id, :payer_plan_period_id, :disease_class_source_value, :revenue_code_source_value],
      :procedure_occurrence=>[:procedure_occurrence_id, :person_id, :procedure_concept_id, :procedure_date, :procedure_type_concept_id, :associated_provider_id, :visit_occurrence_id, :relevant_condition_concept_id, :procedure_source_value],
      :provider=>[:provider_id, :npi, :dea, :specialty_concept_id, :care_site_id, :provider_source_value, :specialty_source_value],
      :relationship=>[:relationship_id, :relationship_name, :is_hierarchical, :defines_ancestry, :reverse_relationship],
      :schema_info=>[:version],
      :source_to_concept_map=>[:source_code, :source_vocabulary_id, :source_code_description, :target_concept_id, :target_vocabulary_id, :mapping_type, :primary_map, :valid_start_date, :valid_end_date, :invalid_reason],
      :visit_occurrence=>[:visit_occurrence_id, :person_id, :visit_start_date, :visit_end_date, :place_of_service_concept_id, :care_site_id, :place_of_service_source_value],
      :vocabulary=>[:vocabulary_id, :vocabulary_name],
    }

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

      attr :nodifier, :values, :options, :arguments, :upstreams

      option :label, type: :string

      @validations = []

      class << self
        attr :validations

        def register(file, *data_models)
          data_models.each do |dm|
            OPERATORS[dm][File.basename(file).sub(/\.rb\z/, '')] = self
          end
        end

        def query_columns(*tables)
          define_method(:query_cols) do
            table_columns(*tables)
          end
        end

        def default_query_columns
          define_method(:query_cols) do
            SELECTED_COLUMNS
          end
        end

        validation_meths = (<<-END).split.map(&:to_sym)
          no_upstreams
          one_upstream
          at_least_one_upstream
          at_most_one_upstream
        END

        validation_meths.each do |type|
          meth = :"validate_#{type}"
          define_method(meth) do |*args|
            validations << [meth, *args]
          end
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@validations, validations.dup)
        end

        def new(*)
          operator = super

          # If operator has a label, replace it with a recall so all references
          # to it use the same code.
          if operator.label
            operator = Operators::Recall.new(operator.nodifier, operator.label)
          end

          operator
        end
      end

      def initialize(nodifier, *args)
        @nodifier = nodifier
        @options = args.extract_options!.deep_rekey
        @upstreams, @arguments = args.partition { |arg| arg.is_a?(Array) || arg.is_a?(Operator) }
        @values = args
        scope.nest(self) do
          create_upstreams
        end
        scope.add_operator(self) if label
      end

      def create_upstreams
        @upstreams.map!{|stmt| to_op(stmt)}
      end

      def to_op(stmt)
        stmt.is_a?(Operator) ? stmt : nodifier.create(*stmt)
      end

      def annotate(db)
        return @annotation if defined?(@annotation)

        scope_key = options[:id]||self.class.just_class_name.underscore
        annotation = {}
        metadata = {:annotation=>annotation}
        if name = self.class.preferred_name
          metadata[:name] = name
        end
        res = [self.class.just_class_name.underscore, *annotate_values(db)] 

        if upstreams_valid?
          scope.with_ctes(evaluate(db), db)
            .from_self
            .select_group(:criterion_type)
            .select_append{count{}.*.as(:rows)}
            .select_append{count(:person_id).distinct.as(:n)}
            .each do |h|
              annotation[h.delete(:criterion_type).to_sym] = h
          end
          types.each do |type|
            counts = annotation[type] ||= {:rows=>0, :n=>0}
            scope.add_counts(scope_key, type, counts)
          end
        elsif !errors.empty?
          annotation[:errors] = errors
          scope.add_errors(scope_key, errors)
        end

        if res.last.is_a?(Hash)
          res.last.merge!(metadata)
        else
          res << metadata
        end

        @annotation = res
      end

      def dup_values(args)
        self.class.new(nodifier, *args)
      end

      def inspect
        "<##{self.class} upstreams=[#{upstreams.map(&:inspect).join(', ')}] arguments=[#{arguments.map(&:inspect).join(', ')}]>"
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

      attr :errors

      def valid?
        return @errors.empty? if defined?(@errors)
        @errors = []
        validate
        errors.empty?
      end

      def upstreams_valid?
        valid? && upstreams.all?(&:upstreams_valid?)
      end

      private

      def scope
        nodifier.scope
      end

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

      def query_cols
        raise NotImplementedError, self
      end

      def query_columns(query)
        unless cols = query.opts[:force_columns]
          cols = query_cols
        end

        if ENV['CONCEPTQL_CHECK_COLUMNS']
          if cols.sort != query.columns.sort
            raise "columns don't match:\nclass: #{self.class}\nexpected: #{cols}\nactual: #{query.columns}\nvalues: #{values}\nSQL: #{query.sql}"
          end
        end

        cols
      end

      def table_cols(table)
        case table
        when Symbol
          table = Sequel.split_symbol(table)[1].to_sym
        end
        TABLE_COLUMNS.fetch(table)
      end

      def table_columns(*tables)
        tables.map{|t| table_cols(t)}.flatten
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
        return :value_as_number if query_columns(query).include?(:value_as_number)
        Sequel.cast_numeric(nil, Float).as(:value_as_number)
      end

      def string_value(query)
        return :value_as_string if query_columns(query).include?(:value_as_string)
        Sequel.cast_string(nil).as(:value_as_string)
      end

      def concept_id_value(query)
        return :value_as_concept_id if query_columns(query).include?(:value_as_concept_id)
        Sequel.cast_numeric(nil).as(:value_as_concept_id)
      end

      def units_source_value(query)
        return :units_source_value if query_columns(query).include?(:units_source_value)
        Sequel.cast_string(nil).as(:units_source_value)
      end

      def source_value(query, type)
        return :source_value if query_columns(query).include?(:source_value)
        Sequel.cast_string(source_value_column(query, type)).as(:source_value)
      end

      def date_columns(query, type = nil)
        return [:start_date, :end_date] if (query_columns(query).include?(:start_date) && query_columns(query).include?(:end_date))
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

      # Validation Related

      def validate
        self.class.validations.each do |args|
          send(*args)
        end
      end

      def validate_no_upstreams
        add_error("has upstreams") unless @upstreams.empty?
      end

      def validate_one_upstream
        validate_at_least_one_upstream
        validate_at_most_one_upstream
      end

      def validate_at_most_one_upstream
        add_error("has multiple upstreams") if @upstreams.length > 1
      end

      def validate_at_least_one_upstream
        add_error("has no upstream") if @upstreams.empty?
      end

      def add_error(*args)
        errors << args
      end
    end
  end
end

# Require all operator subclasses eagerly
Dir.new(File.dirname(__FILE__)).
  entries.
  each{|filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
