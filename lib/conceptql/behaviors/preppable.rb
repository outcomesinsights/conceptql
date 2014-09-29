module ConceptQL
  module Behaviors
    module Preppable
      attr_accessor :prep_proc
      def prep
        prep_proc.call if prep_proc
      end

      def all(*args)
        prep
        super
      end

      def count(*args)
        prep
        super
      end
    end
  end
end
