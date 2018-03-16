module ConceptQL
  module Behaviors
    module Windowable
      def select_it(query, specific_table = nil)
        ds = super
        scope.windows.each{|w| ds = w.call(self, ds)}
        ds
      end
    end
  end
end
