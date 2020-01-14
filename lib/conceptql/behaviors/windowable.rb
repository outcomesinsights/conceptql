module ConceptQL
  module Behaviors
    # Applies scope windows to Operators
    module Windowable
      def evaluate(db, opts = {})
        ds = super(db, opts.merge(required_columns: required_columns | _required_columns))
        ds = apply_windows(ds)
        super(db, opts.merge(ds: ds))
      end

      def apply_windows(ds)
        scope.windows.reduce(ds) do |ds, window|
          window.call(self, ds, timeless: timeless?)
        end
      end

      def _required_columns
        scope.windows
          .select { |w| w.respond_to?(:required_columns) }
          .map(&:required_columns)
          .reduce(:|) || []
      end

      def skip_windows?
        false
      end

      def timeless?
        false
      end
    end
  end
end
