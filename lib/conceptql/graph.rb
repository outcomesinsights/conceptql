require 'psych'
require 'graphviz'
require_relative 'tree'
require_relative 'operators/operator'
require_relative 'behaviors/dottable'

module ConceptQL
  class Graph
    attr :g, :file_path, :dangler, :title, :statement, :db, :suffix
    def initialize(statement, opts = {})
      @statement = statement
      @db = opts.fetch(:db, nil)
      @dangler = opts.fetch(:dangler, false)
      @tree = opts.fetch(:tree, Tree.new)
      @title = opts.fetch(:title, nil)
      @suffix = opts.fetch(:suffix, 'pdf')
      ConceptQL::Operators::Operator.send(:include, ConceptQL::Behaviors::Dottable)
    end

    def graph_it(file_path)
      build_graph(graph)
      graph.output(suffix.to_sym =>  file_path + ".#{suffix}")
    end

    def graph
      @graph ||= begin
        opts = { type: :digraph }
        opts[:label] = title if title
        GraphViz.new(:G, opts)
      end
    end

    private
    attr :tree, :db

    def build_graph(g)
      last_operator = tree.root(self)
      last_operator.graph_it(g, db)
      if dangler
        blank_operator = g.add_nodes("_blank")
        blank_operator[:shape] = 'none'
        blank_operator[:height] = 0
        blank_operator[:label] = ''
        blank_operator[:fixedsize] = true
        last_operator.link_to(g, blank_operator, db)
      end
    end
  end
end

