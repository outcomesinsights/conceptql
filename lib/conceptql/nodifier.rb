require 'facets/hash/deep_rekey'
require 'facets/pathname/chdir'
require 'facets/string/modulize'

module ConceptQL
  class Nodifier
    attr_reader :operators

    def initialize
      @operators = {}
      dir = Pathname.new(__FILE__).dirname()
      dir.chdir do
        Pathname.glob("operators/*.rb").each do |file|
          require_relative file
          operator = file.basename('.*').to_s.to_sym
          klass = Object.const_get("conceptQL/operators/#{operator}".modulize)
          @operators[operator] = klass
        end
      end
    end

    def create(scope, operator, *values)
      operator = operator.to_sym
      if operators[operator].nil?
        raise "Can't find operator for '#{operator}' in #{operators.keys.sort}"
      end
      operator = operators[operator].new(*values)
      operator.scope = scope
      operator
    end

    def to_metadata
      Hash[operators.map { |k, v| [k, v.to_metadata]}.select { |k, v| v[:desc] }]
    end
  end
end
