# frozen_string_literal: true

module ConceptQL
  class NullQuery
    def query
      nil
    end

    def query_cols(_opts = {})
      []
    end

    def sql
      'Cannot generate SQL for empty statement'
    end

    def annotate(_opts = {})
      []
    end

    def scope_annotate(_opts = {})
      {}
    end

    def optimized
      self
    end

    def domains
      []
    end

    def operator
      Operators::Invalid.new(nodifier, 'invalid', errors: [['statement is empy', statement.inspect]])
    end

    def code_list(_db)
      []
    end
  end
end
