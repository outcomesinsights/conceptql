# frozen-string-literal: true

module Sequel
  module ColdColDatabase
    def self.extended(db)
      db.extend_datasets(ColdColDataset)
    end

    def load_schema(path)
      schemas = Psych.load_file(path).map do |table, info|
        columns = info[:columns].map { |column_name, col_info| [column_name, col_info] }
        [literal(table), columns]
      end.to_h
      schemas = (instance_variable_get(:@schemas) || {}).merge(schemas)
      instance_variable_set(:@schemas, schemas)
    end

    def add_table_schema(name, info)
      instance_variable_get(:@schemas)[literal(name)] = info
    end
  end

  module ColdColDataset
    def columns
      columns_search
    end

    def columns_search(opts_chain = nil)
      if (cols = _columns)
        return cols
      end

      unless (pcs = probable_columns(opts.merge(parent_opts: opts_chain))) && pcs.all?
        raise("Failed to find columns for #{sql}")
      end

      self.columns = pcs
    end

    protected

    WILDCARD = Sequel.lit('*').freeze

    def probable_columns(opts_chain)
      if !(cols = opts[:select]).blank?
        from_stars = []

        if has_select_all?(cols)
          from_stars = (opts[:from] || []).flat_map { |from| fetch_columns(from, opts_chain) }
          cols = cols.reject { |c| c == WILDCARD }
        end

        from_stars += cols
                      .select { |c| c.is_a?(Sequel::SQL::ColumnAll) }
                      .flat_map { |c| from_named_sources(c.table.to_sym, opts_chain) }

        cols = cols.reject { |c| c.is_a?(Sequel::SQL::ColumnAll) }

        (from_stars + cols.map { |c| probable_column_name(c) }).flatten
      else
        froms = opts[:from] || []
        joins = (opts[:join] || []).map(&:table_expr)
        (froms + joins).flat_map { |from| fetch_columns(from, opts_chain) }
      end
    end

    private

    def has_select_all?(cols)
      cols.any? { |c| c == WILDCARD }
    end

    def from_named_sources(name, opts_chain)
      schemas = db.instance_variable_get(:@schemas)

      current_opts = opts_chain

      from = (opts[:from] || [])
             .select { |f| f.is_a?(Sequel::SQL::AliasedExpression) }
             .detect { |f| literal(f.alias) == literal(name) }

      return from.expression.columns_search(opts_chain) if from

      with = nil

      while current_opts.present? && with.blank?
        with = (current_opts[:with] || []).detect { |wh| literal(wh[:name]) == literal(name) }
        current_opts = current_opts[:parent_opts]
      end

      # if (join = (opts[:join] || []).detect { |jc| literal(jc.alias) == literal(name) })
      #  jc.table_expr.columns
      # els

      return with[:dataset].columns_search(opts_chain) if with

      if schemas && (table = literal(name)) && (sch = Sequel.synchronize { schemas[table] })
        return sch.map { |c, _| c }
      end

      pp name
      pp opts_chain
      pp sql
      raise("Failed to find columns for #{name}")
    end

    def fetch_columns(from, opts_chain)
      from = from.expression if from.is_a?(SQL::AliasedExpression)

      case from
      when Dataset
        from.columns_search(opts_chain)
      when Symbol, SQL::Identifier, SQL::QualifiedIdentifier
        from_named_sources(from, opts_chain)
      end
    end

    # Return the probable name of the column, or nil if one
    # cannot be determined.
    def probable_column_name(c)
      case c
      when Symbol
        _, c, a = split_symbol(c)
        (a || c).to_sym
      when SQL::Identifier
        c.value.to_sym
      when SQL::QualifiedIdentifier
        c.column.to_sym
      when SQL::AliasedExpression
        a = c.alias
        a.is_a?(SQL::Identifier) ? a.value.to_sym : a.to_sym
      end
    end
  end

  Database.register_extension(:cold_col, Sequel::ColdColDatabase)
end
