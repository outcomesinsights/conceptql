require 'active_support/inflector'
module ConceptQL
  module Behaviors
    module Dottable
      @@counter = 0
      TYPE_COLORS = {
        person: 'blue',
        visit_occurrence: 'orange',
        condition_occurrence: 'red',
        procedure_occurrence: 'green3',
        procedure_cost: 'gold',
        death: 'brown',
        payer_plan_period: 'blue',
        drug_exposure: 'purple',
        observation: 'magenta',
        misc: 'black'
      }
      def node_name
        @__node_name ||= self.class.name.split('::').last.underscore.gsub(/\W/, '_').downcase + '_' + (@@counter += 1).to_s
      end

      def display_name
        @__display_name ||= begin
          output = self.class.name.split('::').last.titleize
          output += ": #{arguments.join(', ')}" unless arguments.empty?
          if output.length > 100
            parts = output.split
            output = parts.each_slice(output.length / parts.count).map do |subparts|
              subparts.join(' ')
            end.join ('\n')
          end
          output += "\n#{options.map{|k,v| "#{k}: #{v}"}.join("\n")}" unless options.nil? || options.empty?
          output
        end
      end

      def type_color(*types)
        types.flatten!
        types.length == 1 ? TYPE_COLORS[types.first] || 'black' : 'black'
      end

      def graph_node(g)
        @__graph_node ||= begin
          me = g.add_nodes(node_name)
          me[:label] = display_name
          me[:color] = type_color(types)
          me
        end
      end

      def link_to(g, dest_node)
        types.each do |type|
          e = g.add_edges(graph_node(g), dest_node)
          e[:color] = type_color(type)
        end
      end

      def graph_it(g, db)
        graph_prep(db) if respond_to?(:graph_prep)
        children.each do |child|
          child.graph_it(g, db)
        end
        graph_node(g)
        children.each do |child|
          child.link_to(g, graph_node(g))
        end
      end
    end
  end
end

