require 'zlib'
require_relative '../behaviors/metadatable'
require 'forwardable'

module ConceptQL
  module Operators
    OPERATORS = {:omopv4_plus=>{}, :gdm=>{}}.freeze

    SELECTED_COLUMNS = [:person_id,
                        :criterion_id,
                        :criterion_table,
                        :criterion_domain,
                        :start_date,
                        :end_date,
                        :value_as_number,
                        :value_as_string,
                        :value_as_concept_id,
                        :units_source_value,
                        :source_value].freeze

    def self.operators
      OPERATORS
    end

    class Operator
      extend Forwardable
      extend ConceptQL::Metadatable

      attr :nodifier, :values, :options, :arguments, :upstreams, :op_name

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
            dm.table_columns(*tables)
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
            operator = Operators::Recall.new(operator.nodifier, "recall", operator.label, replaced: true)
          end

          operator
        end
      end

      def initialize(nodifier, op_name, *args)
        @nodifier = nodifier

        # Under what name was this operator instantiated?
        # For operators like "vocabulary", this tells the instance which
        # vocabulary operator to impersonate
        @op_name = op_name
        @options = {}
        while args.last.is_a?(Hash)
          @options = @options.merge(ConceptQL::Utils.rekey(args.pop))
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
        ConceptQL::Utils.snakecase(self.class.just_class_name)
      end

      def required_columns
        cols = self.class.required_columns || []
        if options[:uuid]
          cols |= [:uuid]
        end
        cols
      end

      def dynamic_columns
        scope.query_columns
      end

      def cte_name(name)
        scope.cte_name(name)
      end

      def annotate(db, opts = {})
        return @annotation if defined?(@annotation)

        scope_key = options[:id] || op_name
        annotation = {}
        counts = (annotation[:counts] ||= {})
        metadata = {:annotation=>annotation}
        if name = preferred_name
          metadata[:name] = name
        end
        res = [op_name, *annotate_values(db, opts)]

        if upstreams_valid?(db, opts) && scope.valid? && include_counts?(db, opts)
          scope.with_ctes(evaluate(db), db)
            .from_self
            .select_group(:criterion_domain)
            .select_append{Sequel.function(:count, 1).as(:rows)}
            .select_append{count(:person_id).distinct.as(:n)}
            .each do |h|
              counts[h.delete(:criterion_domain).to_sym] = h
            end
        elsif !errors.empty?
          annotation[:errors] = errors
          scope.add_errors(scope_key, errors)
        end
        domains(db).each do |domain|
          cur_counts = counts[domain] ||= {:rows=>0, :n=>0}
          scope.add_counts(scope_key, domain, cur_counts)
        end

        if defined?(@warnings) && !warnings.empty?
          annotation[:warnings] = warnings
          scope.add_warnings(scope_key, warnings.dup)
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

      def select_it(query, specific_table = nil)
        specific_table ||= dm.determine_table(:source_table)
        specific_table ||= dm.determine_table(:table)
        specific_table ||= dm.determine_table(:domain)

        dom = domain rescue nil

        opts = {
          table: specific_table,
          criterion_domain: dom,
          query_columns: override_columns,
          uuid: options[:uuid]
        }
        q = dm.selectify(query, opts)

        q
      end

      def override_columns
        nil
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

      def setup_select(query, table = nil)
        query = modify_query(query, table)
        query.select(*columns(table))
      end

      def columns(table = nil)
        #p table
        return dm.columns(table: table)

        cols = unless table
          dynamic_columns
        else
          dm.columns_for_table(table, dynamic_columns)
        end
        return cols

        criterion_table = :criterion_table
        criterion_domain = :criterion_domain
        if local_table
          criterion_table = Sequel.cast_string(local_table.to_s).as(:criterion_table)
          if gdm?
            criterion_domain = Sequel.cast_string(domains(db).first.to_s).as(:criterion_domain)
          else
            criterion_domain = Sequel.cast_string(local_table.to_s).as(:criterion_domain)
          end
        end

        columns = [dm.person_id_column(query),
                   dm.table_id(local_table),
                   criterion_table,
                   criterion_domain]
        columns += dm.date_columns(query, local_table)
        columns += [ source_value(query, local_table) ]
        columns += additional_columns(query, local_table)
        columns
      end

      def label
        @label ||= begin
          options.delete(:label) if options[:label] && options[:label].to_s.strip.empty?
          options[:label].respond_to?(:strip) ? options[:label].strip : options[:label]
        end
      end

      attr :errors, :warnings

      def valid?(db, opts = {})
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

      def gdm?
        data_model == :gdm
      end

      def impala?
        database_type.to_sym == :impala
      end

      def dm
        @dm ||= DataModel.for(self, nodifier)
      end

      def rdbms
        dm.rdbms
      end

      def query_cols
        raise NotImplementedError, self
      end

      private

      def annotate_values(db, opts)
        (upstreams.map { |op| op.annotate(db, opts) } + arguments).push(options)
      end

      def make_table_name(table)
        Sequel.as(table, :tab)
      end

      def query_columns(query)
        dm.query_columns(query)
      end

      def additional_columns(query, table)
        special_columns = {
          provenance_type: Proc.new { provenance_type(query, table) },
          provider_id: Proc.new { provider_id(query, table) },
          visit_source_concept_id: Proc.new { dm.place_of_service_concept_id(query, table) }
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

      def source_value(query, table)
        return :source_value if query_columns(query).include?(:source_value)
        cast_column(:source_value, dm.source_value_column(query, table))
      end

      def source_vocabulary_id(query, table)
        return :source_vocabulary_id if query_columns(query).include?(:source_vocabulary_id)
        cast_column(:source_vocabulary_id, dm.source_vocabulary_id(query, table))
      end

      def provenance_type(query, table)
        return :provenance_type if query_columns(query).include?(:provenance_type)
        cast_column(:provenance_type, dm.provenance_type_column(query, table))
      end

      def provider_id(query, table)
        return :provider_id if query_columns(query).include?(:provider_id)
        cast_column(:provider_id, dm.provider_id_column(query, table))
      end

      def modify_query(query, table)
        {
          visit_source_concept_id: dm.query_modifier_for(:visit_source_concept_id),
          drug_name: dm.query_modifier_for(:drug_name)
        }.each do |column, klass|
          #p [table, column, table, join_id, source_column]
          #p dynamic_columns
          #p query_cols
          next if table.nil?
          next unless dynamic_columns.include?(column)
          query = klass.new(query, self).modified_query
        end

        query
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
        return if @_validated
        @errors = [] unless defined?(@errors)
        @warnings = [] unless defined?(@warnings)

        add_error("invalid label") if label && !label.is_a?(String)
        self.class.validations.each do |args|
          send(*args)
        end

        @_validated = true
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
        return [] unless code_regexp
        return [] if respond_to?(:select_all?) && select_all?
        @bad_arguments ||= arguments.reject do |arg|
          code_regexp === arg
        end
      end

      def code_regexp
        self.class.codes_regexp
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

      def preferred_name
        self.class.pref_name
      end

      def semi_or_inner_join(ds, table, *exprs)
        ds = Sequel[ds] if ds.is_a?(Symbol)
        table = Sequel[table] if table.is_a?(Symbol)
        expr = exprs.inject(&:&)
        if use_inner_join?
          ds.join(table.as(:r), expr)
            .select(*query_cols.map { |c| Sequel[:l][c] })
        else
          rdbms.semi_join(ds, table, *exprs)
        end
      end

      def use_inner_join?
        options[:inner_join]
      end
    end
  end
end

# Require all operator subclasses eagerly
Dir.new(File.dirname(__FILE__)).
  entries.
  each{|filename| require_relative filename if filename =~ /\.rb\z/ && filename != File.basename(__FILE__)}
ConceptQL::Operators.operators.values.each(&:freeze)
