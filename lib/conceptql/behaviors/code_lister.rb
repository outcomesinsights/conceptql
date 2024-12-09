# frozen_string_literal: true

module ConceptQL
  module Behaviors
    module CodeLister
      ConceptCode = Struct.new(:vocabulary, :code, :description) do
        def to_s
          if description
            "#{vocabulary} #{code}: #{description}"
          else
            "#{vocabulary} #{code}"
          end
        end
      end

      def code_list(db)
        describe_codes(db, arguments).map do |code, desc|
          ConceptCode.new(preferred_name, code, desc)
        end
      end
    end
  end
end
