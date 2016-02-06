require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    attr :scope, :data_model, :algorithm_fetcher

    def initialize(scope, opts={})
      @scope = opts[:scope] || Scope.new
      @data_model = opts[:data_model] || :omopv4
      @algorithm_fetcher = opts[:algorithm_fetcher] || (proc do |alg|
        nil
      end)
    end

    def create(operator, *values)
      if operator.to_s == 'algorithm'
        statement, desc = algorithm_fetcher.call(values.first)
        raise "Can't find algorithm for '#{values.first}'" unless statement
        create(*statement)
      else
        unless klass = operators[operator.to_s]
          raise "Can't find operator for '#{operator}' in #{operators.keys.sort}"
        end
        klass.new(self, *values)
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
