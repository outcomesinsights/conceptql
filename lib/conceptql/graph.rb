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
      build_graph(g)
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
    attr :yaml, :tree, :db

    def build_graph(g)
      tree.root(self).each.with_index do |last_node, index|
        last_node.build_temp_tables(db)
        last_node.graph_it(g, db)
        if dangler
          blank_node = g.add_nodes("_#{index}")
          blank_node[:shape] = 'none'
          blank_node[:height] = 0
          blank_node[:label] = ''
          blank_node[:fixedsize] = true
          last_node.link_to(g, blank_node, db)
        end
      end
    end
  end
end

