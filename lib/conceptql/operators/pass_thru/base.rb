require_relative "../base"

module ConceptQL
  module Operators
    module PassThru
      class Base < Operators::Base
        register __FILE__

        basic_type :set
        no_desc

        def domains(db)
          doms = upstreams.compact.flat_map { |up| up.domains(db) }.uniq
          doms.empty? ? [:invalid] : doms
        end

        def query_cols
          upstreams.map(&:query_cols).inject(:|)
        end
      end
    end
  end
end
