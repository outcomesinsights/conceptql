# frozen_string_literal: true

require 'ostruct'

module ConceptQL
  class Columnizer
    class ColumnDefinition
      attr_reader :name, :options

      def initialize(name, options)
        @name = name
        @options = OpenStruct.new(options)
      end

      def grouped?
        options.grouped
      end

      def sequelized
        col = name
        if (q = options.qualifer)
          col = Sequel.qualify(q, col)
        end

        if (fun = options.function)
          col = Sequel.function(fun, col)
        end

        unless options.no_alias
          n = extract_name(name)
          col = Sequel.expr(col).as(n) if ConceptQL::Utils.present?(n)
        end

        col
      end

      def extract_name(name)
        return name if name.is_a?(Symbol)

        n = nil
        n = name.column if name.respond_to?(:column)
        return n unless ConceptQL::Utils.blank?(n)

        n = name.table if name.respond_to?(:table)
        return n unless ConceptQL::Utils.blank?(n)

        extract_name(name.expr) if name.respond_to?(:expr)
      end
    end

    attr_reader :columns

    def initialize
      @columns = {}
    end

    def add_columns(*column_names)
      opts = ConceptQL::Utils.extract_opts!(column_names)
      column_names.map { |cn| cn.respond_to?(:to_sym) ? cn.to_sym : cn }
      column_names.each do |column_name|
        columns[column_name] = ColumnDefinition.new(column_name, opts)
      end
    end

    def apply(query)
      grouped, ungrouped = columns.values.partition(&:grouped?)
      select_method = :select
      unless grouped.empty?
        query = query.select_group(*grouped.map(&:sequelized))
        select_method = :select_append
      end

      return if ungrouped.empty?

      query.send(select_method, *ungrouped.map(&:sequelized))
    end
  end
end
