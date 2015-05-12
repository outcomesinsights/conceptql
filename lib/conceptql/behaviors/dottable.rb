require 'facets/string/snakecase'

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

      def operator_number
        @__operator_number ||= (@@counter += 1)
      end

      def reset_operator_number
        @@counter = 0
      end

      def operator_name
        @__operator_name ||= self.class.name.split('::').last.snakecase.gsub(/\W/, '_').downcase + "_#{operator_number}"
      end

      def display_name
        @__display_name ||= begin
          output = self.class.name.split('::').last.titleize
          #output += " #{operator_number}"
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

      def graph_operator(g)
        @__graph_operator ||= begin
          me = g.add_nodes(operator_name)
          me[:label] = display_name
          me[:color] = type_color(types)
          me[:shape] = shape if respond_to?(:shape)
          me
        end
      end

      def link_to(g, dest_operator, db = nil)
        edge_options = {}

        types.each do |type|
          if db
            my_n = my_n(db, type)
            label = [' rows=' + my_count(db, type).to_s + ' ']
            label << ' n=' + my_n.to_s + ' '
            edge_options[:label] = label.join("\n")
            edge_options[:style] = 'dashed' if my_n.zero?
          end
          e = g.add_edges(graph_operator(g), dest_operator, edge_options)
          e[:color] = type_color(type)
        end
      end

      def graph_it(g, db)
        graph_prep(db) if respond_to?(:graph_prep)
        upstreams.each do |upstream|
          upstream.graph_it(g, db)
        end
        operator = graph_operator(g)
        upstreams.each do |upstream|
          upstream.link_to(g, graph_operator(g), db)
        end
        operator
      end

      def my_count(db, type)
        puts "counting #{operator_name} #{type}"
        evaluate(db).from_self.where(criterion_type: type.to_s).count
      end

      def my_n(db, type)
        evaluate(db).from_self.where(criterion_type: type.to_s).select_group(:person_id).count
      end
    end
  end
end

