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

    attr :known_operators, :recall_stack, :recall_dependencies, :annotation, :extra_ctes

    def initialize
      @known_operators = {}
      @recall_dependencies = {}
      @recall_stack = []
      @annotation = {}
      @extra_ctes = []
      @types_stack = []
      @annotation[:errors] = @errors = {}
      @annotation[:warnings] = @warnings = {}
      @annotation[:counts] = @counts = {}
    end

    def add_errors(key, errors)
      @errors[key] = errors
    end

    def add_warnings(key, errors)
      @warnings[key] = errors
    end

    def add_counts(key, type, counts)
      c = @counts[key] ||= {}
      c[type] = counts
    end

    def add_extra_cte(*args)
      @extra_ctes << args
    end

    def nest(op)
      return yield unless label = op.is_a?(Operators::Recall) ? op.source : op.label

      unless label.is_a?(String)
        op.instance_eval do
          @errors = []
          add_error("invalid label")
        end
        return
      end

      recall_dependencies[label] ||= []

      if recall_stack.include?(label)
        op.instance_eval do
          @errors = []
          add_error("nested recall")
        end
        return
      end

      if known_operators.has_key?(label) && !op.is_a?(Operators::Recall)
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
      if @types_stack.include?(label)
        [:invalid]
      else
        @types_stack << label
        types = if op = fetch_operator(label)
          op.types
        else
          [:invalid]
        end
        @types_stack.pop
        types
      end
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

    def with_ctes(query, db)
      ctes = sort_ctes([], known_operators, recall_dependencies)

      ctes.each do |label, operator|
        query = query.with(label, operator.evaluate(db))
      end
      extra_ctes.each do |label, ds|
        query = query.with(label, ds)
      end

      query
    end

    def fetch_operator(label)
      known_operators[label]
    end
  end
end
