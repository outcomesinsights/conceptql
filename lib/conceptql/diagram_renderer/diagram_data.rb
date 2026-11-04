# frozen_string_literal: true

require "json"

module ConceptQL
  module DiagramRenderer
    # The input handling of the renderer: toDiagramData in
    # frontend/lib/conceptql-diagram/cli/src/render-static.js.
    #
    # The input is parsed JSON (hashes with string keys) in one of three shapes:
    #
    # - a bare node: {"name" => "icd9", ...}
    # - an array of statements: [{"name" => ...}, ...]
    # - {"format" => "conceptql-diagram/v1", "statements" => [...]}, which is
    #   what `conceptql render_json` prints
    #
    # The statements go under a synthetic root with path ids (n0, n0.0, ...).
    # Each node gets outputTypes ["unknown"] when it has none, parameters {}
    # when it has none, and isSelected and isAttachable false. Other keys stay
    # as they are. A bad input raises InputError.
    #
    # The input may also have symbol keys, as ConceptQL::Diagram.render's
    # output has: from writes the input as JSON and reads it back first, so
    # it reads every input as parsed JSON.
    module DiagramData
      FORMAT = "conceptql-diagram/v1"

      module_function

      def from(input)
        statements = statements_of(JSON.parse(JSON.generate(input)))
        raise InputError, "no statements to render" unless statements.is_a?(Array) && !statements.empty?

        children = statements.each_with_index.map { |statement, i| assign(statement, "n#{i}") }
        {
          "name" => "root",
          "id" => "root",
          "isSelected" => false,
          "isAttachable" => false,
          "outputTypes" => children.flat_map { _1["outputTypes"] }.uniq,
          "children" => children
        }
      end

      def statements_of(input)
        if input.is_a?(Array)
          input
        elsif input.is_a?(Hash) && input.key?("statements")
          unless input["format"] == FORMAT
            format = input.key?("format") ? JSON.generate(input["format"]) : "undefined"
            raise InputError, "unsupported format #{format}; expected \"#{FORMAT}\""
          end
          input["statements"]
        elsif input.is_a?(Hash) && input["name"].is_a?(String)
          [ input ]
        else
          raise InputError, 'input must be a diagram node, an array of nodes, or {"format": "conceptql-diagram/v1", "statements": [...]}'
        end
      end

      def assign(node, id)
        raise InputError, "node #{id} has no \"name\"" unless node.is_a?(Hash) && node["name"].is_a?(String)

        output_types = node["outputTypes"]
        parameters = node["parameters"]
        children = node["children"]
        node.merge(
          "id" => id,
          "outputTypes" => JsFormat.truthy?(output_types) && JsFormat.truthy?(JsFormat.length(output_types)) ? output_types : [ "unknown" ],
          "parameters" => JsFormat.truthy?(parameters) ? parameters : {},
          "isSelected" => false,
          "isAttachable" => false,
          "children" => (JsFormat.truthy?(children) ? children : []).each_with_index.map { |child, i| assign(child, "#{id}.#{i}") }
        )
      end

      private_class_method :statements_of, :assign
    end
  end
end
