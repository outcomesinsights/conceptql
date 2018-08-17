module ConceptQL
  module Behaviors
    module Windowable
      def select_it(query, specific_table = nil)
        ds = super
        return ds if respond_to?(:skip_windows?) && skip_windows?
        scope.windows.each{|w| ds = w.call(self, ds)}
        ds
      end
    end
  end
end
