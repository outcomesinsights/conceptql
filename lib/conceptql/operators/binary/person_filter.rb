require_relative "base"

module ConceptQL
  module Operators
    module Binary
      class PersonFilter < Base
        register __FILE__

        desc 'If a result in the left hand results (LHR) matches a person in the right hand results (RHR), it is passed through.'

        def query(db)
          db.from(left.evaluate(db))
            .where(person_id: right.evaluate(db).from_self.select_group(:person_id))
        end
      end
    end
  end
end
