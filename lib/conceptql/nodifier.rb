require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    attr :scope, :data_model, :database_type, :algorithm_fetcher

    def initialize(opts={})
      @scope = opts[:scope] || Scope.new(opts)
      @data_model = opts[:data_model] || :omopv4
      @database_type = opts[:database_type] || :impala
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
        klass.new(self, operator.to_s, *values)
      else
        invalid_op(operator, values, "invalid operator", operator)
      end
    end

    def to_metadata(opts = {})
      Hash[operators.map { |k, v| [k, v.to_metadata(k, opts)]}.select { |k, v| !v[:categories].empty? }.sort_by { |k, v| v[:name] }]
    end

    private

    def operators
      @operators ||= Operators.operators[@data_model]
    end

    def invalid_op(operator, values, *error_args)
      options = values.extract_options!.merge(errors: [error_args])
      values << options
      Operators::Invalid.new(self, operator, *values)
    end
  end
end
