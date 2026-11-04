# frozen_string_literal: true

module ConceptQL
  module DiagramRenderer
    # The input is not a diagram tree that DiagramData accepts (InputError in
    # frontend/lib/conceptql-diagram/cli/src/render-static.js). The message says
    # what is wrong, with the same text as the JavaScript.
    class InputError < StandardError
    end
  end
end
