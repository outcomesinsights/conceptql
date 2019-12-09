module ConceptQL
  JoinTableInfo = Struct.new(:type,
                             :table,
                             :alias,
                             :join_criteria,
                             :for_columns,
                             keyword_init: true
                            )
  class Columns
    attr_reader :available_columns

    PASS_THRU_COLUMNS = proc do |hash, key|
      hash[key] = Sequel.expr(key.to_sym)
    end

    def initialize(available_columns, available_join_tables, rdbms, default_proc = NULL_COLUMNS)
      @available_columns = available_columns
      @available_columns.default_proc = default_proc
      @available_join_tables = available_join_tables
      @rdbms = rdbms
    end

    def evaluate(query, required_columns, opts = {})
      query = add_joins(query, required_columns)
      cols = required_columns.map do |required_column|
        target_col = available_columns[required_column]
        target_col_name = target_col.value.to_sym rescue nil
        unless target_col_name == required_column
          target_col = target_col.as(required_column)
        end
        target_col
      end
      query.select(*cols).from_self
    end

    def add_joins(query, required_columns)
      joins_for(required_columns).inject(query) do |q, jti|
        q.join_table(jti.type,
               jti.table,
               jti.join_criteria, 
               { table_alias: jti.alias })
      end
    end

    def joins_for(required_columns)
      @available_join_tables.select { |jti| !(jti.for_columns & required_columns).empty? }
    end
  end
end
