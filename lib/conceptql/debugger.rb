require_relative 'tree'
require_relative 'operators/operator'
require_relative 'behaviors/debuggable'

module ConceptQL
  class Debugger
    attr :statement, :db, :watch_ids
    def initialize(statement, opts = {})
      @statement = statement
      @db = opts.fetch(:db, nil)
      @tree = opts.fetch(:tree, Tree.new)
      ConceptQL::Operators::Operator.send(:include, ConceptQL::Behaviors::Debuggable)
      @watch_ids = opts.fetch(:watch_ids, [])
      raise "Please specify one or more person_ids you'd like to debug" unless @watch_ids
    end

    def capture_results(path)
      raise "Please specify path for debug file" unless path
      Dir.mktmpdir do |dir|
        dir = Pathname.new(dir)
        operators = tree.root(self)
        operators.first.reset_operator_number
        csv_files = operators.map.with_index do |last_operator, index|
          last_operator.print_results(db, dir, watch_ids)
        end.flatten
        system("csv2xlsx #{path} #{csv_files.join(' ')}")
      end
    end

    private
    attr :yaml, :tree, :db

    def build_graph(g)
      tree.root(self).each.with_index do |last_operator, index|
        last_operator.graph_it(g, db)
        if dangler
          blank_operator = g.add_nodes("_#{index}")
          blank_operator[:shape] = 'none'
          blank_operator[:height] = 0
          blank_operator[:label] = ''
          blank_operator[:fixedsize] = true
          last_operator.link_to(g, blank_operator, db)
        end
      end
    end
  end
end

