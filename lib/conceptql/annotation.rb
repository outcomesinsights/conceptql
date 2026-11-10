# frozen_string_literal: true

require "json"

module ConceptQL
  # Reads a statement that Query#annotate annotated: its operators, their
  # errors and their warnings. It accepts the Ruby result of annotate and the
  # same result parsed back from JSON (string keys), and gives the same answer
  # for both. It reads the statement in its JSON form, so every hash it returns
  # has string keys. See docs/annotation.md.
  #
  # An operator's inputs are its positional upstreams and its left, right and
  # window_table options. A value is an operator only when it is an annotated
  # operator: an Array that starts with a name and holds an annotation hash. So
  # an option whose value is a list of strings is not an operator.
  class Annotation
    # One operator of the statement. #id is its effective id (see
    # Annotation.assign_ids), and #annotation is its annotation hash.
    Operator = Data.define(:name, :id, :annotation)

    # The options that hold an operator's other inputs
    INPUT_OPTIONS = %w[left right window_table].freeze

    class << self
      # Yields each operator node of an annotated statement and its annotation
      # hash, in statement order: an operator, then its inputs in the order of
      # its items.
      def each_node(node, &block)
        return enum_for(__method__, node) unless block

        yield node, annotation_hash(node)
        node.drop(1).each do |item|
          if item.is_a?(Hash)
            INPUT_OPTIONS.each do |key|
              value = lookup(item, key)
              each_node(value, &block) if operator?(value)
            end
          elsif operator?(item)
            each_node(item, &block)
          end
        end
      end

      # Writes the effective id of each operator into its annotation hash, as
      # the first key, :id. It is the operator's id option when the statement
      # gives one. Otherwise it is "<operator>-<n>", where n counts the
      # operators of that name in statement order (icd9-1, icd9-2), and
      # skips any id that the statement gives. The options of the statement
      # are not changed. Query#annotate calls it.
      def assign_ids(annotated)
        nodes = each_node(annotated).to_a
        used = nodes.filter_map { |node, _| given_id(node)&.to_s }.to_set
        counters = Hash.new(0)
        nodes.each do |node, annotation|
          id = given_id(node) || generate_id(node.first.to_s, counters, used)
          annotation.replace({ id: id }.merge(annotation))
        end
        annotated
      end

      private

      def generate_id(name, counters, used)
        loop do
          id = "#{name}-#{counters[name] += 1}"
          return id if used.add?(id)
        end
      end

      def given_id(node)
        option(node, "id")
      end

      def annotation_hash(node)
        option(node, "annotation")
      end

      def option(node, key)
        node.drop(1).each do |item|
          value = lookup(item, key) if item.is_a?(Hash)
          return value unless value.nil?
        end
        nil
      end

      def operator?(value)
        value.is_a?(Array) && (value.first.is_a?(String) || value.first.is_a?(Symbol)) &&
          annotation_hash(value).is_a?(Hash)
      end

      def lookup(hash, key)
        hash.fetch(key) { hash[key.to_sym] }
      end
    end

    def initialize(annotated)
      @annotated = JSON.parse(annotated.to_json)
    end

    # Every operator, root first, in statement order. Without a block, an
    # Enumerator.
    def each_operator
      return enum_for(__method__) unless block_given?

      self.class.each_node(@annotated) do |node, annotation|
        yield Operator.new(name: node.first, id: annotation["id"], annotation: annotation)
      end
    end

    # Every error, as { operator:, id:, message:, details: }
    def errors
      problems("errors")
    end

    # Every warning, in the same form as #errors
    def warnings
      problems("warnings")
    end

    # True when no operator has an error. Warnings do not make a statement
    # invalid.
    def valid?
      errors.empty?
    end

    private

    def problems(kind)
      each_operator.flat_map do |op|
        (op.annotation[kind] || []).map do |message, *details|
          { operator: op.name, id: op.id, message: message, details: details }
        end
      end
    end
  end
end
