# frozen_string_literal: true

require 'json'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/blank'

module ConceptQL
  # Converts ConceptQL statements into trees a diagram renderer can draw.
  #
  # Two shapes are produced:
  #
  # * RenderTree -- the `conceptql-diagram/v1` format: one node per operator,
  #   carrying the operator's metadata (base type, human name) and what
  #   conceptql's own annotation worked out for it (output types, errors,
  #   warnings and, optionally, per-domain counts).
  # * JigsawTree -- the Jigsaw diagram editor's tree JSON (name, values,
  #   parameters, children), as produced by the editor's ConceptqlAdapter.
  module Diagram
    FORMAT = 'conceptql-diagram/v1'

    class << self
      # The full `conceptql-diagram/v1` document for one or more statements.
      #
      # Without `counts: true` no claims database is needed: pass a cdb built
      # on a nil db (the default).
      def render(statements, cdb: default_cdb, counts: false)
        {
          format: FORMAT,
          statements: RenderTree.new(cdb, counts: counts).build_all(statements)
        }
      end

      def default_cdb(data_model = nil)
        opts = {}
        opts[:data_model] = data_model.to_sym if data_model
        ConceptQL::Database.new(nil, opts)
      end

      # A statement file may hold a single statement or a list of them.
      # Mirrors JDE's ConceptqlAdapter#nested.
      def statement_list(statements)
        statements = JSON.parse(statements) if statements.is_a?(String)
        return [] if statements == []
        return statements if statements.first.is_a?(Array)

        [statements]
      end
    end

    class RenderTree
      # Operator options that are structure or bookkeeping, not parameters
      # a diagram should show.
      STRUCTURAL_OPTIONS = %i[annotation name left right id].freeze

      attr_reader :cdb

      def initialize(cdb, counts: false)
        @cdb = cdb
        @counts = counts
      end

      def counts?
        @counts
      end

      def build_all(statements)
        Diagram.statement_list(statements).map { |statement| build(statement) }
      end

      def build(statement)
        node(cdb.query(statement).annotate(skip_counts: !counts?))
      end

      private

      def node(annotated)
        name, *rest = annotated
        hashes, rest = rest.partition { |v| v.is_a?(Hash) }
        opts = hashes.reduce({}, :merge)
        upstreams, values = rest.partition { |v| v.is_a?(Array) }
        annotation = opts[:annotation] || {}

        children = upstreams + opts.values_at(:left, :right).compact
        node = {
          name: name.to_s,
          base: metadata_for(name)[:basic_type]&.to_s,
          humanName: opts[:name] || metadata_for(name)[:preferred_name] || name.to_s
        }
        node[:vocabularyId] = metadata_for(name)[:preferred_name] if vocabulary?(name)
        node.merge!(
          outputTypes: output_types(annotation),
          parameters: opts.except(*STRUCTURAL_OPTIONS),
          values: values,
          children: children.map { |child| node(child) }
        )
        node[:counts] = counts(annotation) if counts?
        node[:errors] = annotation[:errors] if annotation[:errors].present?
        node[:warnings] = annotation[:warnings] if annotation[:warnings].present?
        node
      end

      # conceptql fills annotation[:counts] from Operator#domains, so its keys
      # are the node's output types. Vocabulary metadata nests them
      # ([["condition_occurrence"]]) where cast operators do not ([:person]),
      # so flatten defensively. Sorted so that a counted run (whose keys arrive
      # in database order) matches an uncounted one.
      def output_types(annotation)
        (annotation[:counts] || {}).keys.flatten.map(&:to_s).uniq.sort
      end

      def counts(annotation)
        (annotation[:counts] || {})
          .sort_by { |domain, _| domain.to_s }
          .to_h { |domain, c| [domain.to_s, { rows: Integer(c[:rows] || 0), n: Integer(c[:n] || 0) }] }
      end

      def metadata_for(name)
        operators_metadata[canonical_name(name)] || {}
      end

      def operators_metadata
        @operators_metadata ||= ConceptQL.metadata(cdb)[:operators]
      end

      # A single-vocabulary operator (icd9, loinc, ...). Its metadata
      # preferred_name is the vocabulary's ID (Entry#preferred_name:
      # omopv5_id || id, e.g. "ICD9CM", "LOINC"), which a renderer can show
      # when the humanName (the vocabulary's short name) is too long.
      # Multi-vocabulary operators ("CPT or HCPCS") span several IDs, so they
      # are not included.
      def vocabulary?(name)
        klass = operator_classes[canonical_name(name)]
        !klass.nil? && klass <= ConceptQL::Operators::Vocabulary
      end

      def operator_classes
        @operator_classes ||= ConceptQL::Operators.operators.fetch(cdb.opts[:data_model].to_sym)
      end

      def canonical_name(name)
        name = name.to_s
        operators_metadata.key?(name) ? name : aliases[name]
      end

      def aliases
        @aliases ||= operators_metadata.each_with_object({}) do |(name, md), h|
          Array(md[:aliases]).each { |a| h[a.to_s] = name }
        end
      end
    end

    # Port of the Jigsaw diagram editor's ConceptqlAdapter#to_jigsaw_json.
    # The only change is where binary (filter) operators are looked up: the
    # editor asked its Rails-wide cdb, this takes one (db-less by default).
    class JigsawTree
      BINARY_PARAMETERS = %w[left right].freeze
      IGNORED_PARAMETERS = %w[id].freeze

      class Node
        def initialize(operator, binary)
          @operator = operator
          @binary = binary
        end

        def name
          operator[0]
        end

        def values
          operator[1..].select { |v| v.is_a?(String) || v.is_a?(Integer) }
        end

        def parameters
          return unless operator[-1].is_a?(Hash)

          operator[-1]
            .reject { |k, _v| IGNORED_PARAMETERS.include?(k.to_s) }
            .with_indifferent_access
        end

        def children
          operator[1..right_bound].grep(Array)
        end

        def binary?
          @binary.include?(name)
        end

        private

        attr_reader :operator

        def right_bound
          parameters.present? ? -2 : -1
        end
      end

      def initialize(statements, cdb: Diagram.default_cdb)
        @statements = Diagram.statement_list(statements)
        @cdb = cdb
      end

      def to_jigsaw_json
        { name: 'root', children: statements.map { |s| build_node(s) } }
      end

      private

      attr_reader :statements, :cdb

      def binary
        @binary ||= ConceptQL.metadata(cdb)[:operators].select { |_k, v| v[:basic_type] == :filter }.keys
      end

      def build_node(operator)
        node = Node.new(operator, binary)
        {
          name: node.name,
          values: node.values,
          parameters: build_parameters(node),
          children: build_children(node)
        }.reject { |_k, v| v.blank? }
      end

      def build_parameters(node)
        return unless node.parameters

        node.parameters.reject { |p| BINARY_PARAMETERS.include?(p.to_s) }
      end

      def build_children(node)
        kids = node.children.map { |child| build_node(child) }
        kids += build_binary_children(node) if node.binary?
        kids
      end

      def build_binary_children(node)
        return [] unless node.parameters

        BINARY_PARAMETERS.filter_map { |p| build_node(node.parameters[p]) if node.parameters[p] }
      end
    end
  end
end
