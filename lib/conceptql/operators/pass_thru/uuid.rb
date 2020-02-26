require_relative "base"

module ConceptQL
  module Operators
    module PassThru
      class Uuid < Base
        register __FILE__

        desc "Assigns a UUID to each result that passes through"
        allows_one_upstream
        validate_one_upstream
        validate_no_arguments
        require_column :uuid

        def query(db)
          stream.evaluate(db)
        end

        def available_columns
          { uuid: rdbms.uuid }
        end
      end
    end
  end
end

