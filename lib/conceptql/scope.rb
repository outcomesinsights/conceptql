module ConceptQL
  # Scope coordinates the creation of any common table expressions that might
  # be used when a Recall operator is present in the statement.
  #
  # Any time an operator is given a label, it becomes a candidate
  # for a Recall operator to reuse the output of that operator
  # somewhere else in the statement.
  #
  # Scope keeps track of all labeled operators and provides an
  # API for Recall operators to fetch the results/types from
  # labeled operators.
  class Scope
    attr_accessor :person_ids
    attr :known_operators
    def initialize
      @known_operators = {}
    end

    def add_operator(operator)
      known_operators[operator.label] = operator
    end

    def from(db, label)
      ds = db.from(label)

      if ENV['CONCEPTQL_CHECK_COLUMNS']
        # Work around requests for columns by operators.  These
        # would fail because the CTE would not be defined.  You
        # don't want to define the CTE normally, but to allow the
        # columns to still work, send the columns request to the
        # underlying operator.
        op = fetch_operator(label)
        (class << ds; self; end).send(:define_method, :columns) do
          (@main_op ||= op.evaluate(db)).columns
        end
      end

      ds
    end

    def types(label)
      fetch_operator(label).types
    end

    def with_ctes(query, db)
      known_operators.each do |label, operator|
        query = query.with(label, operator.evaluate(db))
      end

      if with = query.opts[:with]
        with.uniq!{|h| h[:name]}
      end

      query
    end

    private

    def fetch_operator(label)
      known_operators[label] || raise("No operator with label: '#{label}'")
    end
  end
end
