module ConceptQL
  class Columns
    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key.to_sym] = Sequel.expr(key.to_sym)
    end

    attr_reader :qualifier

    def initialize(op, default_proc = PASS_THRU_COLUMNS)
      @op = op
      @columns = {
        uuid: proc { |qualifier| op.rdbms.uuid(qualifier) }
      }
      @columns.default_proc = default_proc
      @qualifier = Sequel
    end

    def add_column(name, definition)
      add_columns(name => definition)
    end

    def add_columns(columns)
      @columns = @columns.merge(columns)
    end

    def qualify_columns(qualifier)
      @qualifier = Sequel[qualifier]
    end

    def evaluate(query, opts = {})
      required_columns = opts.fetch(:required_columns)
      cols = required_columns.map do |required_column|
        target_col = @columns[required_column]
        target_col = 
          case target_col
          when Sequel::SQL::Identifier, Symbol
            qualifier[target_col]
          when Proc
            target_col.call(qualifier)
          else
            target_col
          end
        target_col.as(required_column)
      end
      from_self_opts = {}
      from_self_opts[:alias] = opts[:table_alias] if opts[:table_alias]
      query.select(*cols).from_self(from_self_opts)
    end
  end
end
