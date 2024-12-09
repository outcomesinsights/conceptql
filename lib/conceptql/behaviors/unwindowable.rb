# frozen_string_literal: true

module ConceptQL
  module Behaviors
    module Unwindowable
      def skip_windows?
        true
      end
    end
  end
end
