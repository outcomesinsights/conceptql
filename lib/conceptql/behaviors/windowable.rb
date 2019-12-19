module ConceptQL
  module Behaviors
    # Applies scope windows to Operators
    module Windowable
      def evaluate(db, opts = {})
        ds = super(db, opts)
        return ds if skip_windows?
        apply_windows(ds)
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
