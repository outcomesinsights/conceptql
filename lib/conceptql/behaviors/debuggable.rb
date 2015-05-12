require_relative '../behaviors/dottable'
require_relative '../nodes/operator'
require_relative '../nodes/binary_operator_node'
require 'csv'
module ConceptQL
  module Behaviors
    module Debuggable
      include Dottable
      class ResultPrinter
        attr :db, :dir, :type, :watch_ids, :node
        def initialize(db, dir, type, watch_ids, node)
          @db = db
          @dir = dir
          @type = type
          @watch_ids = watch_ids
          @node = node
        end

        def make_file
          CSV.open(file_path, 'w') do |csv|
            csv << ConceptQL::Operators::Operator::COLUMNS
            results.each do |result|
              csv << result
            end
          end
          file_path
        end

        def file_path
          @file_path ||= dir + file_name
        end

        def file_name
          @file_name ||= [node.node_name, abbreviate(type)].join('_')
        end

        def results
          q = node.evaluate(db)
            .from_self
            .where(criterion_type: type.to_s)
          unless watch_ids.empty?
            q = q.where(person_id: watch_ids)
          end

          q.order([:person_id, :criterion_type, :start_date, :end_date, :criterion_id])
            .select_map(ConceptQL::Operators::Operator::COLUMNS)
        end

        def abbreviate(type)
          type.to_s.split('_').map(&:chars).map(&:first).join('')
        end
      end

      def print_results(db, dir, watch_ids)
        print_prep(db) if respond_to?(:print_prep)
        kids = upstreams
        if self.is_a?(ConceptQL::Operators::BinaryOperatorNode)
          kids = [left, right]
        end
        files = kids.map do |upstream|
          upstream.print_results(db, dir, watch_ids)
        end
        files += types.map do |type|
          ResultPrinter.new(db, dir, type, watch_ids, self).make_file
        end
      end
    end
  end
end

