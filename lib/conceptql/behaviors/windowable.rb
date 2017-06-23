module ConceptQL
  module Behaviors
    module Windowable
      def select_it(query, specific_table = nil)
        scope.window.windowfy(self, super)
      end
    end
  end
end
