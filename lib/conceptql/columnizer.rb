require 'ostruct'

module ConceptQL
  class Columnizer
    class ColumnDefinition
      attr :name, :options
      def initialize(name, options)
        @name = name
        @options = OpenStruct.new(options)
      end

      def grouped?
        options.grouped
      end

      def sequelized
        col = name
        if q = options.qualifer
          col = Sequel.qualify(q, col)
        end

        if fun = options.function
          col = Sequel.function(fun, col)
        end

        unless options.no_alias
          col = Sequel.expr(col).as(name)
        end

        col
      end
    end

    attr :columns

    def initialize
      @columns = {}
    end

    def add_columns(*column_names)
      opts = ConceptQL::Utils.extract_opts!(column_names)
      cols = column_names.map(&:to_sym)
      column_names.each do |column_name|
        columns[column_name] = ColumnDefinition.new(column_name, opts)
      end
    end

    def apply(query)
      grouped, ungrouped = columns.values.partition { |c| c.grouped? }
      select_method = :select
      unless grouped.empty?
        query = query.select_group(*grouped.map(&:sequelized))
        select_method = :select_append
      end

      unless ungrouped.empty?
        query = query.send(select_method, *ungrouped.map(&:sequelized))
      end
    end
  end
end
