require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    attr :tree, :data_model, :algorithm_fetcher

    def initialize(tree, opts={})
      @tree = tree
      @data_model = opts[:data_model] || :omopv4
      @algorithm_fetcher = opts[:algorithm_fetcher] || (proc do |alg|
        nil
      end)
    end

    def create(scope, operator, *values)
      if operator.to_s == 'algorithm'
        statement, desc = algorithm_fetcher.call(values.first)
        raise "Can't find algorithm for '#{values.first}'" unless statement
        tree.send(:start_traverse, statement)
      else
        unless klass = operators[operator.to_s]
          raise "Can't find operator for '#{operator}' in #{operators.keys.sort}"
        end
        operator = klass.new(*values)
        operator.scope = scope

        # If operator has a label, replace it with a recall so all references
        # to it use the same code.
        if operator.label
          operator = Operators::Recall.new(operator.label, original: operator)
          operator.scope = scope
        end

        operator
      end
    end

    def to_metadata
      Hash[operators.map { |k, v| [k, v.to_metadata]}.select { |k, v| v[:desc] }]
    end

    private

    def operators
      @operators ||= Operators.operators[@data_model]
    end
  end
end
