require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    def create(scope, operator, *values)
      unless klass = operators[operator.to_s]
        raise "Can't find operator for '#{operator}' in #{operators.keys.sort}"
      end
      operator = klass.new(*values)
      operator.scope = scope
      operator
    end

    def to_metadata
      Hash[operators.map { |k, v| [k, v.to_metadata]}.select { |k, v| v[:desc] }]
    end

    private

    def operators
      Operators.operators
    end
  end
end
