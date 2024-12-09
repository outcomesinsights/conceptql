# frozen_string_literal: true

module ConceptQL
  module Vocabularies
    module Behaviors
      module Sourcish
        def unionable?(other)
          other.is_a?(self.class)
        end

        def union(other)
          dup_values(values + other.values)
        end
      end
    end
  end
end
