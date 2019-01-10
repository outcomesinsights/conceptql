module ConceptQL
  module Behaviors
    module Windowable
      def select_it(query, specific_table = nil)
        ds = super
        return ds if respond_to?(:skip_windows?) && skip_windows?
        timeless = respond_to?(:timeless?) && timeless?
        scope.windows.each{|w| ds = w.call(self, ds, timeless: timeless)}
        ds
      end
    end
  end
end
