require_relative "operators/base"

module ConceptQL
  class Nodifier
    attr_reader :scope, :database_type, :algorithm_fetcher, :dm, :rdbms

    def initialize(opts={})
      @scope = opts[:scope] || Scope.new(opts.delete(:scope_opts) || {})
      @database_type = opts[:database_type] || ConceptQL::DEFAULT_DATA_MODEL
      @algorithm_fetcher = opts[:algorithm_fetcher] || (proc do |alg|
        nil
      end)
      @dm = opts.fetch(:dm)
      @rdbms = opts.fetch(:rdbms)
      @counter = 0
    end

    def create(operator, *values)
      operator = operator.to_s.downcase
      if operator == 'algorithm'
        statement, desc = algorithm_fetcher.call(values.first)
        if statement
          create(*statement)
        else
          invalid_op(operator, values, "invalid algorithm", values.first)
        end
      elsif (klass = fetch_op(operator))
        klass.new(self, operator, id, *values)
      else
        invalid_op(operator, values, "invalid operator", operator)
      end
    end

    def to_metadata(opts = {})
      Hash[operators.map { |k, v| [k, v.to_metadata(k, opts)]}.select { |k, v| !v[:categories].empty? }.sort_by { |k, v| v[:name] }]
    end

    private

    def operators
      @operators ||= Operators.operators.fetch(dm.data_model)
    end

    def fetch_op(operator)
      operators[alias_for(operator)]
    end

    def alias_for(operator)
      operator_aliases[operator] || operator
    end

    def operator_aliases
      @operator_aliases ||= operators.flat_map do |id, klass|
        next unless klass.aliases.present?
        klass.aliases.map { |klass_alias| [klass_alias, id] }
      end.compact.to_h
    end

    def invalid_op(operator, values, *error_args)
      options = values.pop if values.last.is_a?(Hash)
      options ||= {}
      options = options.merge(errors: [error_args])
      values << options
      Operators::Invalid.new(self, id, operator, *values)
    end

    def id
      @counter += 1
    end
  end
end
