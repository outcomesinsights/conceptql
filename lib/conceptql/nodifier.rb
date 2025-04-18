# frozen_string_literal: true

require_relative 'operators/operator'

module ConceptQL
  class Nodifier
    attr_reader :cdb, :scope, :data_model, :database_type, :algorithm_fetcher

    def initialize(cdb, opts = {})
      @cdb = cdb
      @scope = opts[:scope] || Scope.new(opts.delete(:scope_opts) || {})
      @data_model = get_data_model(opts)
      @database_type = opts[:database_type] || cdb.database_type
      @algorithm_fetcher = opts[:algorithm_fetcher] || (proc do |_alg|
        nil
      end)
    end

    def get_data_model(opts)
      (opts[:data_model] || cdb.opts[:data_model] || ENV['CONCEPTQL_DATA_MODEL'] || ConceptQL::DEFAULT_DATA_MODEL).to_sym
    end

    def create(operator, *values)
      operator = operator.to_s.downcase
      if operator == 'algorithm'
        statement, = algorithm_fetcher.call(values.first)
        if statement
          create(*statement)
        else
          invalid_op(operator, values, 'invalid algorithm', values.first)
        end
      elsif (klass = fetch_op(operator))
        klass.new(self, operator, *values)
      else
        invalid_op(operator, values, 'invalid operator', operator)
      end
    end

    def to_metadata(opts = {})
      Hash[operators.map do |k, v|
        [k, v.to_metadata(k, opts)]
      end.reject { |_k, v| v[:categories].empty? }.sort_by { |_k, v| v[:name] }]
    end

    private

    def operators
      @operators ||= Operators.operators.fetch(@data_model)
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
      Operators::Invalid.new(self, operator, *values)
    end
  end
end
