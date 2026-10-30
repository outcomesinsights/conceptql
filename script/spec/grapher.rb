# frozen_string_literal: true

# Writes the graphviz source of a diagram for doc/spec/ from an annotated
# statement (Query#annotate, with JSON string keys). Each node is an operator,
# and each edge carries the rows and people of one criterion_domain.
class SpecGrapher
  COLORS = {
    "person" => "blue", "condition_occurrence" => "red", "procedure_occurrence" => "green3",
    "death" => "brown", "drug_exposure" => "purple", "observation" => "magenta",
    "observation_period" => "gray"
  }.freeze

  def self.dot(annotated)
    new.dot(annotated)
  end

  def initialize
    @counter = 0
    @lines = []
  end

  def dot(annotated)
    root = traverse(annotated)
    @lines << %(_blank [shape=none, height=0, label="", fixedsize=true];)
    link_to(annotated, root, "_blank")
    "digraph G {\n#{@lines.map { |l| "  #{l}" }.join("\n")}\n}\n"
  end

  private

  def quote(str)
    escaped = str.to_s.gsub("\\") { "\\\\" }.gsub('"') { '\\"' }.gsub("\n") { "\\n" }
    "\"#{escaped}\""
  end

  def opts_of(op)
    op.last.is_a?(Hash) ? op.last : {}
  end

  # The counting query has no ORDER BY, so DuckDB returns the domains in a
  # different order on each run, and the edge order changes the drawing. A fixed
  # order makes the PNGs reproducible. Reverse alphabetical order is the order
  # that 46 of the 48 diagrams of the 2026 rewrite happened to have.
  def counts(op)
    (opts_of(op).dig("annotation", "counts") || {}).sort.reverse.to_h
  end

  def color(op)
    domains = counts(op).keys
    return "gray" if domains.empty?

    domains.one? ? COLORS.fetch(domains.first, "gray") : "black"
  end

  def commatize(number)
    number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end

  def link_to(from, from_node, to)
    cs = counts(from)
    @lines << "#{from_node} -> #{to} [color=gray];" if cs.empty?
    cs.each do |domain, c|
      attrs = { "color" => COLORS.fetch(domain, "gray"), "label" => " rows=#{commatize(c['rows'])} \n n=#{commatize(c['n'])}" }
      attrs["style"] = "dashed" if c["n"].to_i.zero?
      @lines << "#{from_node} -> #{to} [#{attrs.map { |k, v| "#{k}=#{quote(v)}" }.join(', ')}];"
    end
  end

  def label_of(op_name, args, opts)
    label = opts["name"] || op_name.to_s.split("_").map(&:capitalize).join(" ")
    label += ":\n#{args.join(', ')}" unless args.empty?
    extra = opts.except("annotation", "name", "left", "right")
    label += "\n#{extra.map { |k, v| "#{k}: #{v}" }.join("\n")}" unless extra.empty?
    label
  end

  # Returns the node that the operator's output edge leaves from.
  def traverse(op)
    op_name, *rest = op
    opts = opts_of(op)
    rest = rest[0..-2] if op.last.is_a?(Hash)
    upstreams, args = rest.partition { |a| a.is_a?(Array) }
    up_nodes = upstreams.map { |u| [ u, traverse(u) ] }
    label = label_of(op_name, args, opts)
    opts["left"] ? binary(op, op_name, label, opts) : node(op, op_name, label, up_nodes)
  end

  def node(op, op_name, label, up_nodes)
    me = "#{op_name}_#{@counter += 1}"
    @lines << "#{me} [label=#{quote(label)}, color=#{quote(color(op))}];"
    up_nodes.each { |u, n| link_to(u, n, me) }
    me
  end

  # A left/right operator is a box with one point for each side.
  def binary(op, op_name, label, opts)
    left_node = traverse(opts["left"])
    right_node = traverse(opts["right"])
    cl = "cluster_#{op_name}_#{@counter += 1}"
    @lines << "subgraph #{cl} {"
    @lines << "  label=#{quote(label)}; color=black; rank=same;"
    @lines << "  #{cl}_left [shape=point, color=#{quote(color(op))}, label=\"\"];"
    @lines << "  #{cl}_right [shape=point, label=\"\"];"
    @lines << "}"
    link_to(opts["left"], left_node, "#{cl}_left")
    link_to(opts["right"], right_node, "#{cl}_right")
    "#{cl}_left"
  end
end
