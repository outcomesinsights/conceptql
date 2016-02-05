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
        query.opts[:with] = reorder_with(with)
      end

      query
    end

    private

    def fetch_operator(label)
      known_operators[label] || raise("No operator with label: '#{label}'")
    end

    # We need to arrange the CTEs so that there are no forward references
    # This means we need to make sure that if CTE A is used in CTE B, CTE A
    # comes before CTE B.
    #
    # My strategy is to loop over all the CTEs, looking for those CTEs
    # whose name don't appear in another CTE, meaning they aren't referenced
    # by any other CTE.
    #
    # We'll pull those CTEs out and them to the beginning of the list of CTEs
    # until all CTEs have been pulled out because all the CTEs that refer to
    # them have already been pulled out.
    #
    # I wonder if there is a simpler way to do this?
    def reorder_with(with)
      revised = Hash[with.map { |h| [h[:name], h[:dataset]] }]
      new_with = []
      while !revised.keys.empty?
        names = revised.keys
        datasets = revised.values
        unreferenced = names.reject do |name|
          datasets.any? { |dataset| /from\s+[`"]#{name}[`"]/i =~ dataset.sql }
        end
        unreferenced.each do |unref|
          new_with.unshift(name: unref, dataset: revised.delete(unref))
        end
      end
      new_with.tap { |w| require 'pp' ; pp w}
    end
  end
end
