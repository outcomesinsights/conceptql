# frozen_string_literal: true

module ConceptQL
  module Vocabularies
    module Behaviors
      module Omopish
        # Overrides Operator#tables
        def tables
          domains
        end

        def vocabulary_condition
          { dm.source_vocabulary_id(domain) => vocabulary_id.to_i }
        end

        def where_clause(_db)
          conds = vocabulary_condition
          conds[dm.source_value_column(domain)] = arguments unless select_all?
          conds
        end

        def query_cols
          dm.table_columns(domain)
        end

        def translated_vocabulary_id
          vocab_entry.omopv4_id
        end
      end
    end
  end
end
