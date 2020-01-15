module ConceptQL
  module Behaviors
    module Nullish
      def null_columns
        proc do |hash, key|
          hash[key.to_sym] = cast_column(key)
        end
      end
    end
  end
end

