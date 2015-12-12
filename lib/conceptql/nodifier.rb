require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    def create(scope, operator, *values)
      unless operators[operator.to_s]
        raise "Can't find operator for '#{operator}' in #{operators.keys.sort}"
      end
      operator = operators[operator].new(*values)
      operator.scope = scope
      operator
    end

    def to_metadata
      Hash[operators.map { |k, v| [k, v.to_metadata]}.select { |k, v| v[:desc] }]
    end

    private

    def operators
      Operator.operators
    end
  end
end
