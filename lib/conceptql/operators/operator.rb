require 'zlib'
require_relative '../behaviors/metadatable'
require 'facets/array/extract_options'
require 'facets/hash/deep_rekey'
require 'forwardable'
require_relative '../query_modifiers/pos_query_modifier'
require_relative '../query_modifiers/drug_query_modifier'

module ConceptQL
  module Operators
    OPERATORS = {:omopv4=>{}, :omopv4_plus=>{}, :oi_cdm=>{}}.freeze

    SELECTED_COLUMNS = [:person_id, :criterion_id, :criterion_table, :criterion_domain, :start_date, :end_date, :value_as_number, :value_as_string, :value_as_concept_id, :units_source_value, :source_value].freeze

    def self.operators
      OPERATORS
    end

    class Operator
      extend Forwardable
      extend ConceptQL::Metadatable

      attr :nodifier, :values, :options, :arguments, :upstreams

      option :label, type: :string

      @validations = []

      class << self
        attr :validations, :codes_regexp, :required_columns

        def register(file, *data_models)
          data_models = OPERATORS.keys if data_models.empty?
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
            dynamic_columns
          end
        end

        def require_column(column)
          @required_columns ||= []
          @required_columns << column
        end

        validation_meths = (<<-END).split.map(&:to_sym)
          no_upstreams
          one_upstream
          at_least_one_upstream
          at_most_one_upstream
          no_arguments
          one_argument
          at_least_one_argument
          at_most_one_argument
          option
          required_options
          codes_match
        END

        validation_meths.each do |type|
          meth = :"validate_#{type}"
          define_method(meth) do |*args|
            validations << [meth, *args]
          end
        end

        def codes_should_match(format)
          @codes_regexp = format
          validate_codes_match
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@validations, validations.dup)
          subclass.instance_variable_set(:@codes_regexp, codes_regexp.dup) if codes_regexp
        end

        def new(*)
          operator = super

          # If operator has a label, replace it with a recall so all references
          # to it use the same code.
          if operator.label && !operator.errors
            operator.scope.add_operator(operator)
            operator = Operators::Recall.new(operator.nodifier, operator.label, replaced: true)
          end

          operator
        end
      end

      def initialize(nodifier, *args)
        @nodifier = nodifier
        @options = {}
        while args.last.is_a?(Hash)
          @options = @options.merge(args.extract_options!.deep_rekey)
        end
        args.reject!{|arg| arg.nil? || arg == ''}
        @upstreams, @arguments = args.partition { |arg| arg.is_a?(Array) || arg.is_a?(Operator) }
        @values = args

        scope.nest(self) do
          create_upstreams
        end
      end

      def create_upstreams
        @upstreams.map!{|stmt| to_op(stmt)}
      end

      def to_op(stmt)
        stmt.is_a?(Operator) ? stmt : nodifier.create(*stmt)
      end

      def operator_name
        self.class.just_class_name.underscore
      end

      def required_columns
        self.class.required_columns
      end

      def dynamic_columns
        scope.query_columns
      end

      def annotate(db, opts = {})
        return @annotation if defined?(@annotation)

        scope_key = options[:id]||self.class.just_class_name.underscore
        annotation = {}
        counts = (annotation[:counts] ||= {})
        metadata = {:annotation=>annotation}
        if name = self.class.preferred_name
          metadata[:name] = name
        end
        res = [operator_name, *annotate_values(db, opts)]

        if upstreams_valid?(db, opts) && scope.valid? && include_counts?(db, opts)
          scope.with_ctes(evaluate(db), db)
            .from_self
            .select_group(:criterion_domain)
            .select_append{count{}.*.as(:rows)}
            .select_append{count(:person_id).distinct.as(:n)}
            .each do |h|
              counts[h.delete(:criterion_domain).to_sym] = h
            end
        elsif !errors.empty?
          annotation[:errors] = errors
          scope.add_errors(scope_key, errors)
        end
        scope.add_operators(self)
        domains(db).each do |domain|
          cur_counts = counts[domain] ||= {:rows=>0, :n=>0}
          scope.add_counts(scope_key, domain, cur_counts)
        end

        if defined?(@warnings) && !warnings.empty?
          annotation[:warnings] = warnings
          scope.add_warnings(scope_key, warnings)
        end

        if res.last.is_a?(Hash)
          res.last.merge!(metadata)
        else
          res << metadata
        end

        @annotation = res
      end

      def code_list(db)
        upstreams.flat_map { |upstream_op| upstream_op.code_list(db) }
      end

      def dup_values(args)
        self.class.new(nodifier, *args)
      end

      def inspect
        "<##{self.class} upstreams=[#{upstreams.map(&:inspect).join(', ')}] arguments=[#{arguments.map(&:inspect).join(', ')}]>"
      end

      def evaluate(db)
        select_it(query(db), db)
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

      def select_it(query, db, specific_table = nil)
        if specific_table.nil? && respond_to?(:source_table) && schema.keys.include?(source_table)
          specific_table = table
        end

        if specific_table.nil? && respond_to?(:table) && schema.keys.include?(table)
          specific_table = table
        end

        q = setup_select(query, db, specific_table)

        if scope && scope.person_ids && upstreams.empty?
          q = q.where(person_id: scope.person_ids).from_self
        end

        q
      end

      def domains(db)
        @domains ||= determine_domains(db)
      end

      def tables
        @tables ||= determine_tables
      end

      def stream
        @stream ||= upstreams.first
      end

      def setup_select(query, db, local_table = nil)
        query = modify_query(query, local_table)
        query.select(*columns(query, db, local_table))
      end

      def columns(query, db, local_table = nil)
        criterion_table = :criterion_table
        criterion_domain = :criterion_domain
        if local_table
          criterion_table = Sequel.cast_string(local_table.to_s).as(:criterion_table)
          if oi_cdm?
            criterion_domain = Sequel.cast_string(domains(db).first.to_s).as(:criterion_domain)
          else
            criterion_domain = Sequel.cast_string(local_table.to_s).as(:criterion_domain)
          end
        end

        columns = [person_id_column(query),
                    table_id(local_table),
                    criterion_table,
                    criterion_domain,
                  ]
        columns += date_columns(query, local_table)
        columns += [ source_value(query, local_table) ]
        columns += additional_columns(query, local_table)
      end

      def label
        @label ||= begin
          options.delete(:label) if options[:label] && options[:label].to_s.strip.empty?
          options[:label].respond_to?(:strip) ? options[:label].strip : options[:label]
        end
      end

      attr :errors, :warnings

      def valid?(db, opts = {})
        return @errors.empty? if defined?(@errors)
        @errors = []
        @warnings = []
        validate(db, opts)
        errors.empty?
      end

      def upstreams_valid?(db, opts = {})
          valid?(db, opts) && upstreams.all?{|u| u.upstreams_valid?(db, opts)}
      end

      def scope
        nodifier.scope
      end

      def data_model
        nodifier.data_model
      end

      def database_type
        nodifier.database_type
      end

      def cast_column(column, value = nil)
        type = Scope::COLUMN_TYPES.fetch(column)
        case type
        when String, :String
          Sequel.cast_string(value).as(column)
        when Date, :Date
          Sequel.cast(value, type).as(column)
        when Float, :Bigint, :Float
          Sequel.cast_numeric(value, type).as(column)
        else
          raise "Unexpected type: '#{type.inspect}' for column: '#{column}'"
        end
      end

      def omopv4_plus?
        data_model == :omopv4_plus
      end

      def omopv4?
        data_model == :omopv4
      end

      def oi_cdm?
        data_model == :oi_cdm
      end

      def impala?
        database_type.to_sym == :impala
      end

      private

      def annotate_values(db, opts)
        (upstreams.map { |op| op.annotate(db, opts) } + arguments).push(options)
      end

      def criterion_id
        return :criterion_id unless oi_cdm?
        Sequel.expr(:id).as(:criterion_id)
      end

      def table_id(table = nil)
        return :criterion_id if table.nil?
        table = :person if table == :death && !oi_cdm?
        Sequel.expr(make_table_id(table)).as(:criterion_id)
      end

      def make_table_id(table)
        if oi_cdm?
          :id
        else
          (table.to_s + '_id').to_sym
        end
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

      def table_to_sym(table)
        case table
        when Symbol
          table = Sequel.split_symbol(table)[1].to_sym
        end
        table
      end

      def table_cols(table)
        table = table_to_sym(table)
        cols = schema.fetch(table).keys
        cols
      end

      def table_columns(*tables)
        tables.map{|t| table_cols(t)}.flatten
      end

      def table_source_value(table)
        source_value_columns.fetch(table_to_sym(table))
      end

      def table_vocabulary_id(table)
        table_vocabulary_ids[table_to_sym(table)]
      end

      def schema
        @schema ||= Psych.load_file(ConceptQL.schemas + "#{data_model}.yml")
      end

      def person_id_column(query, table = nil)
        if oi_cdm?
          return Sequel.expr(:patient_id).as(:person_id) if query_columns(query).include?(:patient_id)
          return Sequel.expr(:id).as(:person_id) if query_columns(query).include?(:birth_date)
        end

        :person_id
      end

      def additional_columns(query, domain)
        special_columns = {
          provenance_type: Proc.new { provenance_type(query, domain) },
          provider_id: Proc.new { provider_id(query, domain) },
          place_of_service_concept_id: Proc.new { place_of_service_concept_id(query, domain) }
        }

        additional_cols = special_columns.each_with_object([]) do |(column, proc_obj), columns|
          columns << proc_obj.call if dynamic_columns.include?(column)
        end

        standard_columns = dynamic_columns - Scope::DEFAULT_COLUMNS.keys
        standard_columns -= special_columns.keys

        standard_columns.each do |column|
          additional_cols << if query_columns(query).include?(column)
            column
          else
            cast_column(column)
          end
        end

        additional_cols
      end

      def source_value(query, domain)
        return :source_value if query_columns(query).include?(:source_value)
        cast_column(:source_value, source_value_column(query, domain))
      end

      def provenance_type(query, domain)
        return :provenance_type if query_columns(query).include?(:provenance_type)
        cast_column(:provenance_type, provenance_type_column(query, domain))
      end

      def provider_id(query, domain)
        return :provider_id if query_columns(query).include?(:provider_id)
        cast_column(:provider_id, provider_id_column(query, domain))
      end

      def place_of_service_concept_id(query, domain)
        return :place_of_service_concept_id if query_columns(query).include?(:place_of_service_concept_id)
        cast_column(:place_of_service_concept_id, place_of_service_concept_id_column(query, domain))
      end

      def date_columns(query, table = nil)
        return [:start_date, :end_date] if (query_columns(query).include?(:start_date) && query_columns(query).include?(:end_date))
        return [:start_date, :end_date] unless table

        date_klass = Date
        if query.db.database_type == :impala
          date_klass = DateTime
        end

        sd = start_date_column(query, table)
        sd = Sequel.cast(Sequel.expr(sd), date_klass).as(:start_date) unless sd == :start_date
        ed = end_date_column(query, table)
        ed = Sequel.cast(Sequel.function(:coalesce, Sequel.expr(ed), start_date_column(query, table)), date_klass).as(:end_date) unless ed == :end_date
        [sd, ed]
      end

      def assign_column_to_table
        schema.each_with_object({}) do |(table, column_info), cols|
          column = yield table, column_info.keys.map(&:to_s)
          cols[table] = column ? column.to_sym : nil
        end
      end

      def start_date_columns
        @start_date_columns ||= assign_column_to_table do |table, columns|
          column = columns.select { |k| k =~ /start_date$/ }.first
          column ||= columns.select { |k| k =~ /date$/ }.first
        end
      end

      def end_date_columns
        @end_date_columns ||= assign_column_to_table do |table, columns|
          column = columns.select { |k| k =~ /end_date$/ }.first
          column ||= columns.select { |k| k =~ /date$/ }.first
        end
      end

      def start_date_column(query, domain)
        if oi_cdm?
          start_date_columns[domain]
        else
          start_date_columns.merge(person: person_date_of_birth(query))[domain]
        end
      end

      def end_date_column(query, domain)
        if oi_cdm?
          end_date_columns[domain]
        else
          end_date_columns.merge(person: person_date_of_birth(query))[domain]
        end
      end

      def source_value_columns
        @source_value_columns ||= assign_column_to_table do |table, columns|
          reggy = /#{table.to_s.split("_").first}_source_value$/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /source_value$/ }.first
        end
      end

      def table_vocabulary_ids
        @table_vocabulary_ids = assign_column_to_table do |table, columns|
          reggy = /#{table.to_s.split("_").first}_source_vocabulary_id/
          column = columns.select { |k| k =~ reggy }.first
          column ||= columns.select { |k| k =~ /_source_vocabulary_id/ }.first
        end
      end

      def id_columns
        @id_columns ||= assign_column_to_table do |table, columns|
          reggy = /#{table.to_s}_id/
          columns.select { |k| k =~ reggy }.first
        end
      end

      def id_column(table)
        return :id if oi_cdm?
        id_columns[table]
      end

      def source_value_column(query, table)
        source_value_columns[table]
      end

      def provenance_type_column(query, domain)
        {
          condition_occurrence: :condition_type_concept_id,
          death: :death_type_concept_id,
          drug_exposure: :drug_type_concept_id,
          observation: :observation_type_concept_id,
          procedure_occurrence: :procedure_type_concept_id
        }[domain]
      end

      def provider_id_column(query, domain)
        {
          condition_occurrence: :associated_provider_id,
          death: :death_type_concept_id,
          drug_exposure: :prescribing_provider_id,
          observation: :associated_provider_id,
          person: :provider_id,
          procedure_occurrence: :associated_provider_id,
          provider: :provider_id
        }[domain]
      end

      def place_of_service_concept_id_column(query, domain)
        return nil if domain.nil?
        return :place_of_service_concept_id if table_cols(domain).include?(:visit_occurrence_id)
        return nil
      end

      def modify_query(query, domain)
        {
          place_of_service_concept_id: ConceptQL::QueryModifiers::PoSQueryModifier,
          drug_name: ConceptQL::QueryModifiers::DrugQueryModifier
        }.each do |column, klass|
          #p [domain, column, table, join_id, source_column]
          #p dynamic_columns
          #p query_cols
          next if domain.nil?
          next unless dynamic_columns.include?(column)
          query = klass.new(query, self).modified_query
        end

        query
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

      def cast_date(db, date)
        case db.database_type
        when :oracle
          Sequel.function(:to_date, date, 'YYYY-MM-DD')
        when :mssql
          Sequel.lit('CONVERT(DATETIME, ?)', date)
        else
          Sequel.cast(date, Date)
        end
      end

      def determine_tables
        if upstreams.empty?
          if respond_to?(:table)
            [table]
          else
            [:invalid]
          end
        else
          tables = upstreams.compact.map(&:tables).flatten.uniq
          tables.empty? ? [:invalid] : tables
        end
      end

      def determine_domains(db)
        if upstreams.empty?
          if respond_to?(:domain)
            [domain]
          else
            [:invalid]
          end
        else
          doms = upstreams.compact.flat_map { |up| up.domains(db) }.uniq
          doms.empty? ? [:invalid] : doms
        end
      end

      # Validation Related

      def upstream_operator_names
        @upstreams.map(&:operator_name)
      end

      def validate(db, opts = {})
        @errors = [] unless defined?(@errors)
        @warnings = [] unless defined?(@warnings)

        add_error("invalid label") if label && !label.is_a?(String)
        self.class.validations.each do |args|
          send(*args)
        end
      end

      def validate_no_upstreams
        add_error("has upstreams", upstream_operator_names) unless @upstreams.empty?
      end

      def validate_one_upstream
        validate_at_least_one_upstream
        validate_at_most_one_upstream
      end

      def validate_at_most_one_upstream
        add_error("has multiple upstreams", upstream_operator_names) if @upstreams.length > 1
      end

      def validate_at_least_one_upstream
        add_error("has no upstream") if @upstreams.empty?
      end

      def validate_no_arguments
        add_error("has arguments", @arguments) unless @arguments.empty?
      end

      def validate_one_argument
        validate_at_least_one_argument
        validate_at_most_one_argument
      end

      def validate_at_most_one_argument
        add_error("has multiple arguments", @arguments) if @arguments.length > 1
      end

      def validate_at_least_one_argument
        add_error("has no arguments") if @arguments.empty?
      end

      def validate_option(format, *opts)
        opts.each do |opt|
          if options.has_key?(opt)
            unless format === options[opt]
              add_error("wrong option format", opt.to_s, options[opt])
            end
          end
        end
      end

      def validate_required_options(*opts)
        opts.each do |opt|
          unless options.has_key?(opt)
            add_error("required option not present", opt.to_s)
          end
        end
      end

      def bad_arguments
        return [] unless self.class.codes_regexp
        @bad_arguments ||= arguments.reject do |arg|
          self.class.codes_regexp === arg
        end
      end

      def validate_codes_match
        unless bad_arguments.empty?
          add_warning("improperly formatted code", *bad_arguments)
        end
      end

      def add_warnings?(db, opts = {})
        @errors.empty? && !no_db?(db, opts)
      end

      def add_error(*args)
        errors << args
      end

      def add_warning(*args)
        warnings << args
      end

      def needs_arguments_cte?(args)
        impala? && arguments.length > 5000
      end

      def arguments_fix(db, args = nil)
        args ||= arguments
        return args unless needs_arguments_cte?(args)
        args = args.dup
        first_arg = Sequel.expr(args.shift).as(:arg)
        args.unshift(first_arg)
        args = args.map { |v| [v] }
        args_cte = db.values(args)
        db[:args]
          .with(:args, args_cte)
          .select(:arg)
      end

      def include_counts?(db, opts)
        !(no_db?(db, opts) || opts[:skip_counts])
      end

      def skip_db?(opts)
        opts[:skip_db]
      end

      def no_db?(db, opts = {})
        no_db = db.nil? || db.adapter_scheme == :mock || skip_db?(opts)
        no_db ||= table_is_missing?(db)
        no_db
      end

      def table_is_missing?(db)
        false
      end
    end
  end
end

# Require all operator subclasses eagerly
Dir.new(File.dirname(__FILE__)).
  entries.
  each{|filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
