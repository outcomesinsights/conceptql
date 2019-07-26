module ConceptQL
  module Window
    # Base class for classes apply scope windows to incoming Datasets
    class Base
      attr_reader :opts

      def initialize(opts = {})
        @opts = opts
      end

      def call(_op, _ds, _options = {})
        raise NotImplementedError
      end

      def event_start_date_column
        Sequel[opts[:event_start_date_column].to_sym]
      end

      def event_end_date_column
        Sequel[opts[:event_end_date_column].to_sym]
      end
    end
  end
end
