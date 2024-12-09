# frozen_string_literal: true

module ConceptQL
  module Behaviors
    # Applies scope windows to Operators
    module Windowable
      def select_it(query, opts = {})
        ds = super
        return ds if skip_windows?

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
