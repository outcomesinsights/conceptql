module ConceptQL
  module Behaviors
    # Applies scope windows to Operators
    module Windowable
      def evaluate(db, opts = {})
        return super(db, opts) if skip_windows?
        ds = apply_windows(query(db))
        super(db, opts.merge(ds: ds))
      end

      def apply_windows(ds)
        scope.windows.each do |window|
          ds = window.call(self, ds, timeless: timeless?)
        end
        ds
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
