require_relative 'utils/temp_table'
module ConceptQL
  # Scope coordinates the creation of any TempTables that might
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
      @flagged = {}
    end

    def add_operator(operator)
      # Recall operators respond to source, so when we add such an
      # operator, we want to flag it so that we can come back to it later
      # and create the appropriate temp tables
      if operator.respond_to?(:source)
        flagged[operator.source] = true
      end
      return unless operator.label
      known_operators[operator.label] = operator
    end

    def from(db, label)
      temp_table(db, label).from(db)
    end

    def types(label)
      fetch_operator(label).types
    end

    def sql(db)
      temp_tables(db).values.map do |temp|
        temp.sql(db)
      end
    end

    def prep(db)
      temp_tables(db).values.map do |temp|
        temp.build(db)
      end
    end

    private
    attr :flagged

    def temp_tables(db)
      Hash[flagged.keys.map do |label|
        [label, TempTable.new(fetch_operator(label), db)]
      end]
    end

    def temp_table(db, label)
      temp_tables(db)[label]
    end

    def fetch_operator(label)
      known_operators[label] || raise("No operator with label: '#{label}'")
    end
  end
end
