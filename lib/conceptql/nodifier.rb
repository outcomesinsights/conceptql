require 'active_support/inflector'
module ConceptQL
  class Nodifier
    def create(type, values, tree)
      require_relative "nodes/#{type}"
      "conceptQL/nodes/#{type}".camelize.constantize.new(tree, values)
    end
  end
end
