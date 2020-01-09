module ConceptQL
  class Columns
    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key.to_sym] = Sequel.expr(key.to_sym)
    end

    attr_reader :qualifier

    def initialize(op, default_proc = PASS_THRU_COLUMNS)
      @op = op
      @columns = {}
      @columns.default_proc = default_proc
      @qualifier = Sequel
      @op_qualifier = Sequel[op.qualifier]
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

    def allow_comments?
      ENV["CONCEPTQL_ENABLE_COMMENTS"] == "true"
    end

    def has_column?(column_name)
      @columns.has_key?(column_name)
    end

    def evaluate(query, opts = {})
      more_cols = opts.delete(:additional_columns) || {}
      query.auto_columns(@columns.merge(more_cols))
      query.auto_qualify(qualifier)

      return query.auto_select(opts)

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

      q = query
        .select(*cols)
        .from_self({alias: opts[:table_alias] || @op_qualifier})
      q = q.comment(@op.comment) if allow_comments?
      q
    end
  end
end
