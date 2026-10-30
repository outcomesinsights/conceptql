# frozen_string_literal: true

module ConceptQL
  # Counts the rows and the distinct people of every operator in a statement
  # with one SQL statement, for Operator#annotate. The SQL statement is the
  # root query's CTEs plus a UNION ALL of one count for each operator's CTE.
  #
  # This needs MATERIALIZED CTEs, so that each CTE runs once. Spark does not
  # honor MATERIALIZED, so on Spark each operator counts its rows with its own
  # query (Operator#domain_counts). That per-operator path is also used when
  # the statement has an operator that #annotate does not count (an invalid
  # operator, or no database), with temp tables instead of CTEs, and with the
  # Database's share_utilization option, whose tables are not CTEs.
  #
  # Nothing runs until the first operator asks for its counts.
  class OneQueryCounts
    OPERATOR_COLUMN = :conceptql_operator

    def initialize(root, db, opts)
      @root = root
      @db = db
      @opts = opts
    end

    # The counts of op as { criterion_domain => { rows:, n: } }, without the
    # domains that have no rows. nil if this statement cannot be counted with
    # one SQL statement.
    def for(op)
      counts&.fetch(op)
    end

    # The SQL statement that counts every operator, or nil.
    def dataset
      return @dataset if defined?(@dataset)

      @dataset = build_dataset
    end

    private

    attr_reader :root, :db, :opts

    def scope
      root.scope
    end

    def counts
      return @counts if defined?(@counts)

      @counts = dataset && read_counts
    end

    def read_counts
      by_index = Array.new(@operators.length) { {} }
      dataset.each do |h|
        by_index[h[OPERATOR_COLUMN]][h[:criterion_domain].to_sym] = { rows: h[:rows], n: h[:n] }
      end
      @operators.zip(by_index).to_h.compare_by_identity
    end

    def build_dataset
      return unless root.rdbms.supports_materialized?
      return if scope.force_temp_tables? || ConceptQL.avoid_ctes?

      @operators = operators
      return unless @operators.all? { |op| op.countable?(db, opts) }

      query, relations = root_query
      # A Union reads its Vocabulary upstreams with one combined query, so the
      # root query has no CTE for them. Their own CTEs join the WITH list.
      unless relations.all?
        extra = @operators.zip(relations).filter_map { |op, name| op.evaluate(db) unless name }
        query, relations = root_query(extra)
        return unless relations.all?
      end

      query.from(relations.each_with_index.map { |name, i| count_query(name, i) }
                          .reduce { |all, one| all.union(one, all: true, from_self: false) })
    end

    # The root query, and the name of the CTE in its WITH list that holds the
    # rows of each operator (nil when it has none).
    def root_query(extra = [])
      query = scope.with_ctes(root, db, extra: extra)
      with_names = Array(query.opts[:with]).map { |w| w[:name] }
      [ query, @operators.map { |op| scope.cte_names(op).reverse.find { |name| with_names.include?(name) } } ]
    end

    # Every operator that #annotate visits: the statement's tree, and the
    # labeled operators that Recall operators stand in for.
    def operators
      found = []
      visit = lambda do |op|
        next if op.nil? || found.any? { |known| known.equal?(op) }

        found << op
        op.all_upstreams.each(&visit)
      end
      visit.call(root)
      scope.known_operators.each_value(&visit)
      found
    end

    def count_query(name, index)
      db[name].select_group(:criterion_domain)
              .select_append(Sequel.as(index, OPERATOR_COLUMN))
              .select_append { Sequel.function(:count, 1).as(:rows) }
              .select_append { count(:person_id).distinct.as(:n) }
    end
  end
end
