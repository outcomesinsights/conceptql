require_relative 'tree'
require_relative 'nodes/node'
require_relative 'behaviors/debuggable'

module ConceptQL
  class Debugger
    attr :statement, :db, :watch_ids
    def initialize(statement, opts = {})
      @statement = statement
      @db = opts.fetch(:db, nil)
      @tree = opts.fetch(:tree, Tree.new)
      ConceptQL::Operators::Node.send(:include, ConceptQL::Behaviors::Debuggable)
      @watch_ids = opts.fetch(:watch_ids, [])
      raise "Please specify one or more person_ids you'd like to debug" unless @watch_ids
    end

    def capture_results(path)
      raise "Please specify path for debug file" unless path
      Dir.mktmpdir do |dir|
        dir = Pathname.new(dir)
        nodes = tree.root(self)
        nodes.first.reset_node_number
        csv_files = nodes.map.with_index do |last_node, index|
          last_node.print_results(db, dir, watch_ids)
        end.flatten
        system("csv2xlsx #{path} #{csv_files.join(' ')}")
      end
    end

    private
    attr :yaml, :tree, :db

    def build_graph(g)
      tree.root(self).each.with_index do |last_node, index|
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

