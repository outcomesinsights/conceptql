module ConceptQL
  module Window
    class Table
      attr :table_window

      def initialize(table_window)
        @table_window = table_window
      end

      def windowfy(op, query)
        query.from_self(alias: :og)
          .join(table_window, { person_id: :person_id }, table_alias: :tw)
          .where(Sequel.qualify(:tw, :start_date) <= Sequel.qualify(:og, :start_date))
          .where(Sequel.qualify(:og, :end_date) <= Sequel.qualify(:tw, :end_date))
      end
    end
  end
end

