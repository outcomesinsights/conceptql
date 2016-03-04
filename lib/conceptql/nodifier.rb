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
        if statement
          create(*statement)
        else
          invalid_op(operator, values, "invalid algorithm", values.first)
        end
      elsif klass = operators[operator.to_s]
        klass.new(self, *values)
      else
        invalid_op(operator, values, "invalid operator", operator)
      end
    end

    def to_metadata
      Hash[operators.map { |k, v| [k, v.to_metadata]}.select { |k, v| v[:desc] }]
    end

    private

    def operators
      @operators ||= Operators.operators[@data_model]
    end

    def invalid_op(operator, values, *error_args)
      options = values.extract_options!.merge(errors: error_args)
      values << options
      Operators::Invalid.new(self, operator, *values)
    end
  end
end
