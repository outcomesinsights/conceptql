require 'active_support/inflector'
module ConceptQL
  class Nodifier
    def create(type, values)
      require_relative "nodes/#{type}"
      "conceptQL/nodes/#{type}".camelize.constantize.new(values)
    end
  end
end
