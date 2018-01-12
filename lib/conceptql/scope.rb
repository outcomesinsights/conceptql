require_relative "window"
require "securerandom"


module ConceptQL
  # Scope coordinates the creation of any common table expressions that might
  # be used when a Recall operator is present in the statement.
  #
  # Any time an operator is given a label, it becomes a candidate
  # for a Recall operator to reuse the output of that operator
  # somewhere else in the statement.
  #
  # Scope keeps track of all labeled operators and provides an
  # API for Recall operators to fetch the results/domains from
  # labeled operators.
  class Scope
    DEFAULT_COLUMNS = {
      person_id: :Bigint,
      criterion_id: :Bigint,
      criterion_table: :String,
      criterion_domain: :String,
      start_date: :Date,
      end_date: :Date,
      source_value: :String
    }.freeze

    ADDITIONAL_COLUMNS = {
      value_as_number: :Float,
      value_as_string: :String,
      value_as_concept_id: :Bigint,
      unit_source_value: :String,
      visit_occurrence_id: :Bigint,
      provenance_type: :Bigint,
      provider_id: :Bigint,
      place_of_service_concept_id: :Bigint,
      range_low: :Float,
      range_high: :Float,
      drug_name: :String,
      drug_amount: :Float,
      drug_amount_units: :String,
      drug_days_supply: :Float,
      drug_quantity: :Bigint
    }.freeze

    COLUMN_TYPES = (DEFAULT_COLUMNS.merge(ADDITIONAL_COLUMNS)).freeze

    attr_accessor :person_ids

    attr :known_operators, :recall_stack, :recall_dependencies, :annotation, :opts, :query_columns

    def initialize(opts = {})
      @known_operators = {}
      @recall_dependencies = {}
      @recall_stack = []
      @label_cte_names = {}
      @annotation = {}
      @opts = opts.dup
      @annotation[:errors] = @errors = {}
      @annotation[:warnings] = @warnings = {}
      @annotation[:counts] = @counts = {}
      @query_columns = DEFAULT_COLUMNS.keys


      @i = 0
      @mutex = Mutex.new
      @cte_name_next = lambda{@mutex.synchronize{@i+=1}}

      if force_temp_tables? && ConceptQL::Utils.blank?(scratch_database)
        raise ArgumentError, "You must set the DOCKER_SCRATCH_DATABASE environment variable to the name of the scratch database if using the CONCEPTQL_FORCE_TEMP_TABLES environment variable"
      end
    end

    def add_errors(key, errors)
      @errors[key] = errors
    end

    def add_warnings(key, errors)
      @warnings[key] = errors
    end

    def add_counts(key, domain, counts)
      c = @counts[key] ||= {}
      c[domain] = counts
    end

    def add_required_columns(op)
      @query_columns |= op.required_columns if op.required_columns
    end

    def nest(op)
      add_required_columns(op)
      return yield unless label = op.is_a?(Operators::Recall) ? op.source : op.label

      unless label.is_a?(String)
        op.instance_eval do
          @errors = []
          add_error("invalid label")
        end
        return
      end

      recall_dependencies[label] ||= []

      if nested_recall?(label)
        op.instance_eval do
          @errors = []
          add_error("nested recall")
        end
        return
      end

      if duplicate_label?(label) && !op.is_a?(Operators::Recall)
        op.instance_eval do
          @errors = []
          add_error("duplicate label")
        end
      end

      if last = recall_stack.last
        recall_dependencies[last] << label
      end

      begin
        recall_stack.push(label)
        yield
      ensure
        recall_stack.pop if recall_stack.last == label
      end
    end

    def add_operator(operator)
      known_operators[operator.label] = operator
    end

    def duplicate_label?(label)
      known_operators.keys.map(&:downcase).include?(label.downcase)
    end

    def nested_recall?(label)
      recall_stack.map(&:downcase).include?(label.downcase)
    end

    def from(db, label)
      ds = db.from(label_cte_name(label))

      if ENV['CONCEPTQL_CHECK_COLUMNS']
        # Work around requests for columns by operators.  These
        # would fail because the CTE would not be defined.  You
        # don't want to define the CTE normally, but to allow the
        # columns to still work, send the columns request to the
        # underlying operator.
        op = fetch_operator(label)
        ds = ds.with_extend do
          define_method(:columns) do
            (@main_op ||= op.evaluate(db)).columns
          end
        end
      end

      ds
    end

    def domains(label, db)
      fetch_operator(label).domains(db)
    rescue
      [:invalid]
    end

    def sort_ctes(sorted, unsorted, deps)
      if unsorted.empty?
        return sorted
      end

      add, unsorted = unsorted.partition do |label, _|
        deps[label].length == 0
      end

      sorted += add

      new_deps = {}
      deps.map do |label, dps|
        new_deps[label] = dps - sorted.map(&:first)
      end

      sort_ctes(sorted, unsorted, new_deps)
    end

    def valid?
      recall_dependencies.each_value do |deps|
        unless (deps - known_operators.keys).empty?
          return false
        end
      end
      true
    end

    def recursive_extract_cte_expr(t, ctes)
      case t
      when Sequel::Dataset
        recursive_extract_ctes(t, ctes)
      when Sequel::SQL::AliasedExpression
        if t.expression.is_a?(Sequel::Dataset)
          Sequel.as(recursive_extract_ctes(t.expression, ctes), t.alias)
        else
          t
        end
      else
        t
      end
    end

    def recursive_extract_ctes(query, ctes)
      #puts
      #p [:rec, ctes, query.opts]

      if from = query.opts[:from]
        from = from.map{|t| recursive_extract_cte_expr(t, ctes)}
        query = query.clone(:from=>from.map{|t| recursive_extract_cte_expr(t, ctes)})
        #p [:rec_from, ctes.map(&:first), from]
      end

      if joins = query.opts[:join]
        query = query.clone(:join=>joins.map{|jc| jc.class.new(jc.on, jc.join_type, recursive_extract_cte_expr(jc.table_expr, ctes))})
        #p [:rec_join, ctes.map(&:first), joins]
      end

      if compounds = query.opts[:compounds]
        query = query.clone(:compounds=>compounds.map{|t,ds,a| [t, recursive_extract_ctes(ds, ctes),a]})
        #p [:rec_compounds, ctes.map(&:first), compounds]
      end

      if with = query.opts[:with]
        ctes.concat(with.map{|w| [w[:name], recursive_extract_ctes(w[:dataset], ctes)]})
        #p [:rec_with, ctes.map(&:first), with]
        query = query.clone(:with=>nil)
      end


      query
    end

    def with_ctes(query, db)
      #puts
      #p [:with_ctes, query]
      raise "recall operator use without matching label" unless valid?
      query = query.from_self
      temp_tables = ctes.map do |label, operator|
        [label_cte_name(label), operator.evaluate(db)]
      end

      if force_temp_tables?
        query = recursive_extract_ctes(query, temp_tables).with_extend do
          # Create temp tables for each CTE
          #
          # Need to override multiple methods if sequel_pg is in use, as in
          # that case not every method calls each.  For other adapters or
          # when sequel_pg is not in use, it is probably safe to override just each.
          # There are other methods that may need to be overridden in order to handle
          # all cases when sequel_pg is in use.
          [:each, :to_hash_groups, :to_hash].each do |meth|
            define_method(meth) do |*args, &block|
              if !temp_tables.empty? && !opts[:conceptql_temp_tables_created]
                begin
                  temp_tables.each do |table_name, ds|
                    #p [:create_table, table_name]
                    db.create_table(table_name, as: ds)
                  end

                  clone(:conceptql_temp_tables_created=>true).send(meth, *args, &block)
                ensure
                  temp_tables.reverse_each do |table_name,_|
                    #p [:drop_table, table_name]
                    begin
                      db.drop_table?(table_name, cascade: true)
                    rescue Sequel::DatabaseError
                      warn("Unable to drop scratch table: #{literal(table_name)}")
                    end
                  end
                end
              else
                super(*args, &block)
              end
            end
          end

          define_method(:sql_statements) do |*args, &block|
            sql_statements = temp_tables.map do |table_name, ds|
              [table_name, ds.sql]
            end.compact.push([:query, sql(*args, &block)])
            Hash[sql_statements]
          end
        end
      else
        temp_tables.each do |table_name, ds|
          query = query.with(table_name, ds)
        end

        query = query.with_extend do
          define_method(:sql_statements) do |*args, &block|
            { query: sql(*args, &block) }
          end
        end
      end

      query
    end

    def label_cte_name(label)
      @label_cte_names[label] ||= cte_name(label)
    end

    def ctes
      @ctes ||= sort_ctes([], known_operators, recall_dependencies)
    end

    def fetch_operator(label)
      known_operators[label]
    end

    def window
      @window ||= Window.from(opts)
    end

    def force_temp_tables?
      opts[:force_temp_tables]
    end

    def scratch_database
      opts[:scratch_database]
    end

    def cte_name(name)
      name = Sequel.identifier("#{name}_#{$$}_#{@cte_name_next.call}_#{SecureRandom.hex(16)}")

      if scratch_database
        name = name.qualify(scratch_database)
      end

      name
    end
  end
end
