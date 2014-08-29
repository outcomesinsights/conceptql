require 'active_support/inflector'
module ConceptQL
  class Nodifier
    def create(type, values, tree)
      require_relative "nodes/#{type}"
      node = "conceptQL/nodes/#{type}".camelize.constantize.new(values)
      node.tree = tree
      node
    end
  end
end
