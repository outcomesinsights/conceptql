require_relative "../base"
module ConceptQL
  module Operators
    module Selection
      class Base < Operators::Base
        include ConceptQL::Behaviors::Windowable
        include ConceptQL::Behaviors::Timeless

        class QueryAssembler
          class SafeContext
            attr_reader :op, :required_columns, :query_columns

            def initialize(op, *required_columns)
              @op = op
              @required_columns = required_columns.map(&:to_sym)
              @query_columns = op.scope.query_columns
            end

            def method_missing(meth, *args)
              meth = meth.to_sym

              unless required_columns.include?(meth)
                raise "#{op.op_name} is trying to use #{meth} but didn't declare it"
              end

              primary_table_alias[meth]
            end

            def primary_table
              @primary_table ||= op.table || tables.first
            end

            def tables
              op.dm.nschema.tables_by_column(*required_columns)
            end

            def primary_table_name
              Sequel[primary_table.name]
            end

            def primary_table_alias
              @primary_table_alias ||= Sequel[primary_table.as_name(op).to_sym]
            end
          end

          attr_reader :ctx, :op

          def initialize(op)
            @op = op
            @ctx = SafeContext.new(op, :gender_concept_id)
          end

          def to_query(db)
            ds = op.from(db, ctx)
            ds = op.apply_where(ds, ctx)
            ds = apply_select(ds)
            ds = apply_external_joins(ds)
            ds
          end

          def apply_where(ds)
            return ds unless op.respond_to?(:where_clause)
            ds.where(op.where_clause(ds, ctx))
          end
        end

        class TableTracker
          attr_reader :name, :op

          def initialize(name, op)
            @name = name.to_sym
            @op = op
          end
          
          def alias
            "#{name}_#{op.alias}"
          end
        end

        class Columns
          attr_reader :available_columns

          def initialize(available_columns)
            @available_columns = available_columns
          end

          def add_column(name, definition)
            @available_columns[name] = definition
          end

          def add_columns(new_columns)
            @available_columns = @available_columns.merge(new_columns)
          end

          def selection_columns(required_columns)
            required_columns.map do |column|
              @available_columns[column]
            end
          end
        end

        def where_clauses(db)
          [where_clause(db)]
        end

        def where_clause(db)
          raise NotImplementedError
        end

        def query(db)
          ds = db[table.name]
          ds = where_clauses(db).inject(ds) do |ds, where_clause|
            ds.where(where_clause)
          end
          ds
        end

        def table
          raise NotImplementedError
        end

        def evaluate(db, required_columns = Scope::DEFAULT_COLUMNS.keys)
          query(db)
            .select(*columns.selection_columns(required_columns))
            .from_self(alias: table_alias)
        end

        def columns
          @columns ||= Columns.new(
            Scope::COLUMN_TYPES.keys.map { |c| [c, rdbms.process(c, nil)] }.to_h
          ).tap do |c| 
            names = table.columns.map(&:name)
            c.add_columns(names.zip(names).to_h)
          end
        end

        def table_alias
          op_name.to_sym
        end
      end
    end
  end
end

