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

    attr :known_operators, :recall_stack, :recall_dependencies, :annotation, :opts, :query_columns, :nodifier

    def initialize(opts = {})
      @known_operators = {}
      @recall_dependencies = {}
      @recall_stack = []
      @annotation = {}
      @nodifier = nodifier
      @opts = opts.dup
      @annotation[:errors] = @errors = {}
      @annotation[:warnings] = @warnings = {}
      @annotation[:counts] = @counts = {}
      @annotation[:operators] = @operators = []
      @query_columns = DEFAULT_COLUMNS.keys
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

    def add_operators(operator)
      @operators << operator.operator_name
      @operators.compact!
      @operators.uniq!
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

    def with_ctes(query, db)
      raise "recall operator use without matching label" unless valid?

      query = query.from_self

      ctes.each do |label, operator|
        query = query.with(label, operator.evaluate(db))
      end

      query
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

    class Window
      class << self
        def from(opts)
          start_date = opts[:start_date]
          end_date = opts[:end_date]
          window_table = opts[:window_table]

          if start_date && end_date
            return DateLiteralWindow.new(start_date, end_date)
          elsif window_table
            TableWindow.new(window_table)
          else
            new
          end
        end
      end

      def windowfy(op, query)
        query
      end
    end

    class DateLiteralWindow
      attr :window_start, :window_end

      def initialize(start_date, end_date)
        @window_start = start_date
        @window_end = end_date
      end

      def windowfy(op, query)
        start_check = op.rdbms.cast_date(window_start) <= :start_date
        end_check = Sequel.expr(:end_date) <= op.rdbms.cast_date(window_end)
        query.from_self.where(start_check).where(end_check)
      end
    end

    class TableWindow
      attr :table_window

      def initialize(table_window)
        @table_window = table_window
      end

      def windowfy(op, query)
        query.from_self(alias: :og)
          .join(table_window, { person_id: :person_id }, table_alias: :tw)
          .where(Sequel.qualify(:tw, :start_date) <= Sequel.qualify(:og, :start_date))
          .where(Sequel.qualify(:og, :end_date) <= Sequel.qualify(:tw, :end_date))
      end
    end
  end
end
