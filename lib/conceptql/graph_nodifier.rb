require_relative 'behaviors/dottable'
require_relative 'nodes/operator'

module ConceptQL
  class GraphNodifier
    class DotNode < ConceptQL::Operators::Operator
      include ConceptQL::Behaviors::Dottable

      TYPES = {
        # Conditions
        condition: :condition_occurrence,
        primary_diagnosis: :condition_occurrence,
        icd9: :condition_occurrence,
        icd10: :condition_occurrence,
        condition_type: :condition_occurrence,
        medcode: :condition_occurrence,

        # Procedures
        procedure: :procedure_occurrence,
        cpt: :procedure_occurrence,
        drg: :procedure_occurrence,
        hcpcs: :procedure_occurrence,
        icd9_procedure: :procedure_occurrence,
        procedure_cost: :procedure_cost,
        medcode_procedure: :procedure_occurrence,

        # Visits
        visit_occurrence: :visit_occurrence,
        place_of_service: :visit_occurrence,
        place_of_service_code: :visit_occurrence,

        # Person
        person: :person,
        gender: :person,
        race: :person,

        # Payer
        payer: :payer_plan_period,

        # Death
        death: :death,

        # Observation
        loinc: :observation,
        from_seer_visits: :observation,
        to_seer_visits: :observation,

        # Drug
        drug_exposure: :drug_exposure,
        rxnorm: :drug_exposure,
        drug_cost: :drug_cost,
        drug_type_concept_id: :drug_exposure,
        drug_type_concept: :drug_exposure,
        prodcode: :drug_exposure,

        # Date Operators
        date_range: :date,

        # Miscelaneous nodes
        concept: :misc,
        vsac: :misc
      }

      attr :values, :name
      def initialize(name, values)
        @name = name.to_s
        super(values)
      end

      def display_name
        @__display_name ||= begin
          output = @name.dup
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

      def types
        types = [TYPES[name.to_sym] || upstreams.map(&:types)].flatten.uniq
        types.empty? ? [:misc] : types
      end
    end

    class BinaryOperatorNode < DotNode
      def display_name
        output = name
        output += "\n#{displayable_options.map{|k,v| "#{k}: #{v}"}.join("\n")}"
        output
      end

      def displayable_options
        options.select{ |k,v| ![:left, :right].include?(k) } || {}
      end

      def left
        options[:left]
      end

      def right
        options[:right]
      end

      def graph_it(g, db)
        left.graph_it(g, db)
        right.graph_it(g, db)
        cluster_name = "cluster_#{node_name}"
        me = g.send(cluster_name) do |sub|
          sub[rank: 'same', label: display_name, color: 'black']
          sub.send("#{cluster_name}_left").send('[]', shape: 'point', color: type_color(types))
          sub.send("#{cluster_name}_right").send('[]', shape: 'point')
        end
        left.link_to(g, me.send("#{cluster_name}_left"))
        right.link_to(g, me.send("#{cluster_name}_right"))
        @__graph_node = me.send("#{cluster_name}_left")
      end

      def types
        left.types
      end

      def arguments
        options.values
      end
    end

    class LetNode < DotNode
      def graph_it(g, db)
        cluster_name = "cluster_#{node_name}"
        linkable = nil
        g.send(cluster_name) do |sub|
          linkable = upstreams.reverse.map do |upstream|
            upstream.graph_it(sub, db)
          end.first
          sub[label: display_name, color: 'black']
        end
        @__graph_node = linkable
      end

      def types
        upstreams.last.types
      end
    end

    class DefineNode < DotNode
      def shape
        :cds
      end
    end

    class RecallNode < DotNode
      def shape
        :cds
      end
    end

    class VsacNode < DotNode
      def initialize(name, values, types)
        @types = types
        super(name, values)
      end

      def types
        [ @types ].flatten.compact.map(&:to_sym)
      end
    end

    BINARY_OPERATOR_TYPES = %w(before after meets met_by started_by starts contains during overlaps overlapped_by finished_by finishes coincides except person_filter less_than less_than_or_equal equal not_equal greater_than greater_than_or_equal filter).map { |temp| [temp, "not_#{temp}"] }.flatten.map(&:to_sym)

    def temp_tables
      @temp_tables ||= {}
    end

    def types
      @types ||= {}
    end

    def create(type, values, tree)
      node = if BINARY_OPERATOR_TYPES.include?(type)
        BinaryOperatorNode.new(type, values)
      elsif type == :let
        LetNode.new(type, values)
      elsif type == :define
        DefineNode.new(type, values)
      elsif type == :recall
        RecallNode.new(type, values)
      elsif type == :vsac
        types = values.pop
        VsacNode.new(type, values, types)
      else
        DotNode.new(type, values)
      end
      node.tree = self
      node
    end
  end
end
