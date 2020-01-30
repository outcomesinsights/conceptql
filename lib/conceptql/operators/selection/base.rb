require_relative "../base"
module ConceptQL
  module Operators
    module Selection
      class Base < Operators::Base
        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Selectable

        def where_clauses(db)
          [where_clause(db)].compact
        end

        def where_clause(db)
          raise NotImplementedError
        end

        def query(db, opts = {})
          ds = db[table.name]
          ds = where_clauses(db).inject(ds) do |ds, where_clause|
            ds.where(where_clause)
          end
          prepare_columns(ds)
        end

        def table
          raise NotImplementedError
        end

        def prepare_columns(ds, opts = {})
          names = table.columns.map(&:name)
          make_selectable(ds)
            .auto_columns(names.zip(names).to_h)
        end

        def table_alias
          op_name.to_sym
        end
      end
    end
  end
end
