module ConceptQL
  class Columns
    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key.to_sym] = Sequel.expr(key.to_sym)
    end

    def initialize(op, default_proc = PASS_THRU_COLUMNS)
      @op = op
      @columns = {
        uuid: op.rdbms.uuid
      }
      @columns.default_proc = default_proc
    end

    def add_column(name, definition)
      add_columns(name => definition)
    end

    def add_columns(columns)
      @columns = @columns.merge(columns)
    end

    def evaluate(query, required_columns, opts = {})
      cols = required_columns.map do |required_column|
        target_col = @columns[required_column]
        target_col_name = target_col.value.to_sym rescue nil
        unless target_col_name == required_column
          target_col = Sequel[target_col].as(required_column)
        end
        target_col
      end
      from_self_opts = {}
      from_self_opts[:alias] = opts[:table_alias] if opts[:table_alias]
      query.select(*cols).from_self(from_self_opts)
    end
  end
end
