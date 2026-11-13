# frozen_string_literal: true

require "English"
require_relative "window"
require "securerandom"
require "sequel"

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
    # Raised when the extracted CTEs read each other in a cycle, so no order
    # puts every CTE after the CTEs it reads.
    class CteCycleError < StandardError
      def initialize(names)
        super("These CTEs read each other in a cycle, so they have no valid order: #{names.join(', ')}")
      end
    end

    DEFAULT_COLUMN_FAMILY = "default"

    DEFAULT_COLUMNS = {
      person_id: :Bigint,
      criterion_id: :Bigint,
      criterion_table: :String,
      criterion_domain: :String,
      start_date: :Date,
      end_date: :Date,
      source_value: :String,
      source_vocabulary_id: :String,
      label: :String,
      column_family: :String
    }.freeze

    ADDITIONAL_COLUMNS = {
      value_as_number: :Float,
      value_as_string: :String,
      value_as_concept_id: :Bigint,
      value_as_concept: :String,
      unit_concept_id: :Bigint,
      unit_concept: :String,
      context_id: :Bigint,
      visit_occurrence_id: :Bigint,
      file_provenance_type: :Bigint,
      code_provenance_type: :Bigint,
      provider_id: :Bigint,
      context_specialty_concept_id: :Bigint,
      practitioner_specialty_concept_id: :Bigint,
      role_type_concept_id: :Bigint,
      visit_source_concept_id: :Bigint,
      range_low: :Float,
      range_high: :Float,
      drug_name: :String,
      drug_amount: :Float,
      drug_amount_units: :String,
      drug_strength_source_value: :String,
      drug_days_supply: :Bigint,
      drug_quantity: :Float,
      admission_date: :Date,
      discharge_date: :Date,
      length_of_stay: :Bigint,
      admission_source_value: :String,
      admission_source_description: :String,
      discharge_location_source_value: :String,
      discharge_location_source_description: :String,
      primary_concept_id: :Bigint,
      primary_diagnosis_code: :String,
      primary_diagnosis_vocabulary: :String,
      uuid: :String,
      window_id: :Bigint
    }.freeze

    COLUMN_TYPES = DEFAULT_COLUMNS.merge(ADDITIONAL_COLUMNS).freeze

    # Marks the WITH entry of a list that the Database's share_utilization
    # option keeps in a shared table (Behaviors::Utilizable#evaluate).
    SHARED_TABLE = :conceptql_shared_table

    attr_accessor :person_ids

    # The OneQueryCounts that Operator#annotate reads its counts from, or nil.
    # Query#annotate sets it.
    attr_accessor :one_query_counts

    attr_reader :known_operators, :recall_stack, :recall_dependencies, :opts, :query_columns

    def initialize(opts = {})
      @known_operators = {}
      @recall_dependencies = {}
      @recall_stack = []
      @label_cte_names = {}
      @operator_cte_names = {}.compare_by_identity
      @opts = opts.dup
      @query_columns = DEFAULT_COLUMNS.keys
      @query_columns << :window_id if window_opts[:window_table]

      @i = 0
      @mutex = Mutex.new
      @cte_name_next = -> { @mutex.synchronize { @i += 1 } }

      return unless force_temp_tables? && scratch_database.to_s.empty?

      raise ArgumentError,
            "You must set the DOCKER_SCRATCH_DATABASE environment variable to the name of the scratch database if using the CONCEPTQL_FORCE_TEMP_TABLES environment variable"
    end

    # Operator#evaluate records the name of each CTE that holds an operator's
    # rows. An operator evaluated more than once has more than one name.
    def record_cte(op, name)
      (@operator_cte_names[op] ||= []) << name
    end

    def cte_names(op)
      @operator_cte_names.fetch(op, [])
    end

    def add_required_columns(op)
      @query_columns |= op.required_columns if op.required_columns
    end

    def harvest_person_ids(op)
      if (person_ids = op.options[:person_ids])
        opts[:person_ids] = person_ids
      end
    end

    def nest(op)
      add_required_columns(op)
      harvest_person_ids(op)
      return yield unless (label = op.is_a?(Operators::Recall) ? op.source : op.label)

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

      if (last = recall_stack.last)
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
      if ConceptQL.avoid_ctes?
        ds = db.from(fetch_operator(label).evaluate(db).as(label_cte_name(label)))
      else
        ds = db.from(label_cte_name(label))

        if ENV["CONCEPTQL_CHECK_COLUMNS"]
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
      end

      ds
    end

    def domains(label, db)
      fetch_operator(label).domains(db)
    rescue StandardError
      [ :invalid ]
    end

    def sort_ctes(sorted, unsorted, deps)
      return sorted if unsorted.empty?

      add, unsorted = unsorted.partition do |label, _|
        deps[label].empty?
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
        return false unless (deps - known_operators.keys).empty?
      end
      true
    end

    # An IN list of at least this many integers (concept IDs, mostly) goes to
    # the database once, as a CTE that each copy of the list reads
    # (concept_list_condition). Postgres spends planning time on each copy of
    # a long IN list: one 111-operator algorithm spent 485 ms planning 52
    # copies of 2,442-item provenance lists, and 156 ms with one CTE for each
    # list. A shorter list stays an IN list, because a list CTE can change the
    # Postgres plan for the worse: with a 231-item list as a CTE, the count
    # statement of a test statement ran in 36 ms instead of 14 ms.
    CONCEPT_LIST_MIN_ITEMS = 1000

    # Takes the CTEs out of the datasets in an expression, and replaces its
    # long IN lists with concept lists. With datasets: false, it leaves the
    # datasets as they are (for a SELECT list). With concept_lists: false, it
    # leaves the IN lists as they are. With not_in_lists: false, it leaves the
    # NOT IN lists as they are.
    class CteExtractor < Sequel::ASTTransformer
      def initialize(scope, ctes, db, datasets: true, concept_lists: true, not_in_lists: true)
        super()
        @scope = scope
        @ctes = ctes
        @db = db
        @datasets = datasets
        @concept_lists = concept_lists
        @not_in_lists = not_in_lists
      end

      private

      def v(o)
        if o.is_a?(Sequel::Dataset)
          @datasets ? @scope.recursive_extract_ctes(o, @ctes) : o
        elsif @concept_lists && @scope.concept_list?(o) && (@not_in_lists || o.op == :IN)
          @scope.concept_list_condition(o, @db, @ctes, v(o.args.first))
        else
          super
        end
      end
    end

    # True for an IN or NOT IN condition on a list of at least
    # CONCEPT_LIST_MIN_ITEMS integers.
    def concept_list?(expr)
      expr.is_a?(Sequel::SQL::BooleanExpression) && %i[IN NOT\ IN].include?(expr.op) &&
        (list = expr.args[1]).is_a?(Array) && list.length >= CONCEPT_LIST_MIN_ITEMS && list.all?(Integer)
    end

    # expr (a concept_list? condition) with its list replaced by a subquery
    # of the CTE that holds the list. Each distinct list has one CTE in the
    # scope, which joins ctes. The rows are the same: the list has no NULL.
    def concept_list_condition(expr, db, ctes, column)
      ids = expr.args[1]
      name = (@concept_lists ||= {})[ids] ||= cte_name(:concept_list)
      ctes << [ name, concept_list_dataset(db, ids), @concept_list_options || {} ]
      Sequel::SQL::BooleanExpression.new(expr.op, column, db.from(name).select(:concept_id))
    end

    # One concept_id column with a row for each ID, in SQL that Postgres,
    # DuckDB and Spark all accept.
    def concept_list_dataset(db, ids)
      rows = ids.map { |id| "(#{db.literal(id)})" }.join(", ")
      alias_sql = "#{db.literal(Sequel.identifier(:t))}(#{db.literal(Sequel.identifier(:concept_id))})"
      db.dataset.with_sql("SELECT * FROM (VALUES #{rows}) AS #{alias_sql}")
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
      # puts
      # p [:rec, ctes, query.opts]

      if (with = query.opts[:with])
        keep, remove = with.partition { |w| w[:no_temp_table] }
        ctes.concat(remove.map do |w|
          opts = w.except(:name, :dataset, :no_temp_table)
          # A shared table is created from its whole list, nested CTEs included.
          ds = w[SHARED_TABLE] ? w[:dataset] : recursive_extract_ctes(w[:dataset], ctes)
          [ w[:name], ds, opts ]
        end)
        # p [:rec_with, ctes.map(&:first), with]
        query = query.clone(with: keep.empty? ? nil : keep)
      end

      if (from = query.opts[:from])
        query = query.clone(from: from.map { |t| recursive_extract_cte_expr(t, ctes) })
        # p [:rec_from, ctes.map(&:first), from]
      end

      if (joins = query.opts[:join])
        query = query.clone(join: joins.map do |jc|
          table_expr = recursive_extract_cte_expr(jc.table_expr, ctes)
          # A CROSS JOIN is a plain JoinClause, with no ON condition.
          if jc.respond_to?(:on)
            jc.class.new(jc.on, jc.join_type, table_expr)
          else
            jc.class.new(jc.join_type, table_expr)
          end
        end)
        # p [:rec_join, ctes.map(&:first), joins]
      end

      if (compounds = query.opts[:compounds])
        query = query.clone(compounds: compounds.map { |t, ds, a| [ t, recursive_extract_ctes(ds, ctes), a ] })
        # p [:rec_compounds, ctes.map(&:first), compounds]
      end

      # Spark rejects a NOT IN subquery in a nested condition, so there a
      # NOT IN list stays a NOT IN list. @not_in_concept_lists and
      # @select_concept_lists are nil when with_ctes did not run (a direct
      # call), and nil rewrites.
      not_in_lists = @not_in_concept_lists != false
      if (where = query.opts[:where])
        query = query.clone(where: CteExtractor.new(self, ctes, query.db, not_in_lists: not_in_lists).transform(where))
      end

      # One In Two Out flags its events with CASE expressions on the same
      # provenance lists as its WHERE. Spark rejects an IN subquery in a
      # SELECT list, so there the lists stay IN lists.
      if (select = query.opts[:select])
        extractor = CteExtractor.new(self, ctes, query.db, datasets: false, concept_lists: @select_concept_lists != false, not_in_lists: not_in_lists)
        query = query.clone(select: extractor.transform(select))
      end

      query
    end

    # Removes duplicate CTE names, then moves each CTE after the CTEs it reads.
    #
    # A CTE reads another when its SQL contains the other's name as the
    # adapter quotes it (ds.db.literal): "name" on Postgres and DuckDB,
    # `name` on Spark, and "scratch"."name" for a temp table in a scratch
    # database. The closing quote stops a name from matching the start of a
    # longer name. Each name also ends with the scope's counter and 32 random
    # hex digits, so a name does not appear in other SQL by accident.
    #
    # The sort is stable: each step takes the first CTE whose dependencies are
    # already placed. recursive_extract_ctes appends the CTEs that a dataset
    # reads before the dataset itself, so an order that is already correct
    # does not change. (sort_ctes sorts by layers, and would move CTEs.)
    def sort_extracted_ctes(ctes)
      sorted_ctes_with_sql(ctes).map(&:entry)
    end

    # One extracted CTE in sorted_ctes_with_sql: its [name, dataset, WITH
    # options] entry, its name as the adapter quotes it, its SQL, and the
    # quoted names of the CTEs that its SQL reads.
    SortedCte = Struct.new(:entry, :literal, :sql, :reads)

    # The work of sort_extracted_ctes. It keeps each CTE's SQL, so that
    # merge_identical_ctes does not build it again. The names are compared as
    # quoted strings: a comparison of two Sequel identifiers is much slower.
    def sorted_ctes_with_sql(ctes)
      unsorted = ctes.uniq(&:first).map do |entry|
        name, ds = entry
        SortedCte.new(entry, ds.db.literal(name), ds.sql)
      end
      literals = unsorted.map(&:literal)
      unsorted.each do |cte|
        cte.reads = literals.select { |literal| !literal.equal?(cte.literal) && cte.sql.include?(literal) }
      end

      sorted = []
      placed = Set.new
      until unsorted.empty?
        index = unsorted.index { |cte| cte.reads.all? { |literal| placed.include?(literal) } }
        raise(CteCycleError, unsorted.map(&:literal)) unless index

        cte = unsorted.delete_at(index)
        placed << cte.literal
        sorted << cte
      end
      sorted
    end

    # The opts key of the query that with_ctes returns. Its value maps the
    # name of each CTE that merge_identical_ctes removed to the name of the
    # CTE that the query reads in its place.
    MERGED_CTES = :conceptql_merged_ctes

    # Sorts the extracted CTEs (sort_extracted_ctes) and keeps one CTE of each
    # group of CTEs with the same SQL and WITH options. A statement evaluates
    # some operators more than once (a Recall, or an operator that reads its
    # upstream twice), and each evaluation gives its CTE a new name. Each
    # reader of a removed CTE reads the kept one instead. The CTEs come in
    # dependency order, so a CTE's SQL is compared after the CTEs it reads are
    # renamed. Thus two CTEs that read two copies of one CTE merge too.
    #
    # The CTEs that root_sql reads are never removed, because the root query
    # is a dataset, not SQL text, and its names are not renamed.
    #
    # Each kept CTE's dataset becomes its SQL text (Dataset#with_sql), so the
    # final query does not build that SQL again.
    #
    # Returns the kept [name, dataset, WITH options] entries in dependency
    # order, and a Hash of each removed name to the name that replaces it.
    def merge_identical_ctes(ctes, root_sql)
      renames = {}
      merged = {}
      kept = {}
      pattern = nil
      pattern_size = 0
      entries = sorted_ctes_with_sql(ctes).filter_map do |cte|
        name, ds, with_opts = cte.entry
        sql = cte.sql
        if cte.reads.any? { |literal| renames.key?(literal) }
          unless pattern_size == renames.length
            pattern = Regexp.union(renames.keys)
            pattern_size = renames.length
          end
          sql = sql.gsub(pattern, renames)
        end

        key = [ sql, with_opts ]
        if (same = kept[key]) && !root_sql.include?(cte.literal)
          renames[cte.literal] = same.literal
          merged[name] = same.entry.first
          next
        end

        kept[key] ||= cte
        [ name, ds.db.dataset.with_sql(sql), with_opts ]
      end
      [ entries, merged ]
    end

    # The CTEs of each dataset in extra (an evaluated operator) join the WITH
    # list too, so the query can read operators that op does not evaluate.
    def with_ctes(op, db, options = {}, extra: [])
      raise "recall operator use without matching label" unless valid?

      query = op.evaluate(db)
      extra.each { |ds| query = query.clone(with: query.opts[:with] + ds.opts[:with]) }
      rdbms = op.rdbms
      # A concept list is read by many CTEs, so it runs once.
      @concept_list_options = rdbms.supports_materialized? ? { materialized: true } : {}
      @select_concept_lists = rdbms.supports_in_subquery_in_select?
      @not_in_concept_lists = rdbms.supports_nested_not_in_subquery?

      query = query.from_self
      temp_tables = []
      # With CONCEPTQL_AVOID_CTES, each operator is a subquery
      # (Operator#evaluate) and Scope#from inlines each labeled operator, so
      # nothing is extracted and a long IN list stays an IN list. Only the
      # shared tables (add_shared_table) remain.
      if ConceptQL.avoid_ctes?
        temp_tables.concat(@shared_tables || [])
      else
        ctes.each do |label, operator|
          temp_tables << [ label_cte_name(label), recursive_extract_ctes(operator.evaluate(db), temp_tables) ]
        end
        query = recursive_extract_ctes(query, temp_tables)
      end
      shared_tables, temp_tables = temp_tables.partition { |_, _, with_opts| with_opts&.fetch(SHARED_TABLE, false) }
      shared_tables = shared_tables.uniq(&:first)
      temp_tables, merged = merge_identical_ctes(temp_tables, query.sql)
      query = query.clone(MERGED_CTES => merged)

      if force_temp_tables?(options)
        scope = self
        query = query.with_extend do
          # Create temp tables for each CTE
          #
          # Need to override multiple methods if sequel_pg is in use, as in
          # that case not every method calls each.  For other adapters or
          # when sequel_pg is not in use, it is probably safe to override just each.
          # There are other methods that may need to be overridden in order to handle
          # all cases when sequel_pg is in use.
          %i[each to_hash_groups to_hash].each do |meth|
            define_method(meth) do |*args, &block|
              if !temp_tables.empty? && !opts[:conceptql_temp_tables_created]
                begin
                  temp_tables.each do |table_name, ds, _with_opts|
                    db.create_table(table_name, rdbms.create_options(scope, ds).merge(options).merge(as: ds))
                    rdbms.post_create(db, table_name)
                  end

                  clone(conceptql_temp_tables_created: true).send(meth, *args, &block)
                ensure
                  drop_temp_tables
                end
              else
                super(*args, &block)
              end
            end
          end

          define_method(:columns) do
            if self.db.respond_to?(:record_table)
              temp_tables.each do |table_name, ds, _with_opts|
                self.db.record_table(table_name, self.db.columns_from_sql(ds))
              end
            end
            super()
          end

          define_method(:sql_statements) do |*args, &block|
            sql_statements = temp_tables.map do |table_name, ds|
              [ table_name, ds.sql ]
            end.compact.push([ :query, sql(*args, &block) ])
            Hash[scope.shared_table_statements(shared_tables, op) + sql_statements]
          end

          define_method(:drop_temp_tables) do |opts = {}|
            opts ||= {}
            table_names = temp_tables.reverse_each.map(&:first)
            begin
              db.drop_table?(*table_names, rdbms.drop_options.merge(opts))
            rescue Sequel::DatabaseError
              warn("Unable to drop scratch table: #{literal(*table_names)}")
            end
          end
        end
      else
        temp_tables.each do |table_name, ds, with_opts|
          query = if with_opts.nil? || with_opts.empty?
                    query.with(table_name, ds)
          else
                    query.with(table_name, ds, with_opts)
          end
        end

        scope = self
        query = query.with_extend do
          define_method(:sql_statements) do |*args, &block|
            Hash[scope.shared_table_statements(shared_tables, op).push([ :query, sql(*args, &block) ])]
          end

          define_method(:drop_temp_tables) do |opts = {}|
          end
        end
      end

      shared_tables.empty? ? query : create_shared_tables_on_read(query, shared_tables, op)
    end

    # With CONCEPTQL_AVOID_CTES, Behaviors::Utilizable#evaluate records each
    # shared table here, because with_ctes extracts no WITH entry to find it
    # in. Returns a dataset that reads the table.
    def add_shared_table(db, name, list)
      (@shared_tables ||= []) << [ name, list, { SHARED_TABLE => true } ]
      db[name]
    end

    # The sql_statements entries that create the shared tables that do not
    # exist yet. They come first, because the other entries read them.
    def shared_table_statements(shared_tables, op)
      shared_tables.filter_map { |name, key, _with_opts| op.nodifier.cdb.shared_utilization_statement(name, key) }
    end

    # Creates the shared tables that do not exist yet before the query reads
    # its first rows, for a caller that reads rows through conceptql. This
    # hook runs before the force_temp_tables hook, so the temp tables can read
    # them. The shared tables are never in drop_temp_tables.
    def create_shared_tables_on_read(query, shared_tables, op)
      scope = self
      cdb = op.nodifier.cdb
      rdbms = op.rdbms
      query.with_extend do
        %i[each to_hash_groups to_hash].each do |meth|
          define_method(meth) do |*args, &block|
            shared_tables.each do |name, key, _with_opts|
              cdb.create_shared_utilization_table(name, key, rdbms, scope)
            end
            super(*args, &block)
          end
        end
      end
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

    def windows
      @windows ||= Window.from(window_opts)
    end

    # The window options that run: the scope options, merged with the options
    # of the statement's window (window_opts), which win. A window_table at the
    # top of the scope options is a window table, as one in window_opts is
    # (bead conceptql-6t7q).
    def window_opts
      opts.merge(opts[:window_opts] || {})
    end

    def force_temp_tables?(options = {})
      # opts.fetch(:force_temp_tables, opts[:force_temp_tables])
      options.fetch(:force_temp_tables, opts[:force_temp_tables])
    end

    def scratch_database
      opts[:scratch_database]
    end

    def cte_name(name, options = {})
      cte_parts = [
        opts[:table_prefix],
        name.to_s.gsub(/\W+/, "_"),
        $PROCESS_ID,
        @cte_name_next.call,
        SecureRandom.hex(16)
      ].compact

      name = Sequel.identifier(cte_parts.join("_"))

      name = name.qualify(scratch_database) if force_temp_tables?(options) && scratch_database

      name
    end
  end
end
