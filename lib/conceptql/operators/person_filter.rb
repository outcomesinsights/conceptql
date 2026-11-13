# frozen_string_literal: true

require_relative "binary_operator_operator"

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__
      effects :keep

      desc "Keeps each left-hand result whose patient has at least one result in the right-hand stream. The type and the dates of the right-hand results do not matter."
      returns "The left-hand results of every type whose patient has at least one right-hand result. The right-hand results are not returned."
      option_meaning :right, "The right-hand stream. The operator keeps the left-hand results of each patient who has a result in this stream, and does not pass these results on."

      example "All MI Conditions for people who are male",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "gender", "Male" ] } ]
      example "All MI Conditions for people who had an office visit at some point in the dataset",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "cpt", "99214" ] } ]
      example "The same result as the example above, with the office visits converted to patients first",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "person", [ "cpt", "99214" ] ] } ]
      example "All MI Conditions for people who are Male OR had an office visit at some point in the dataset",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "union", [ "cpt", "99214" ], [ "gender", "Male" ] ] } ]
      example "Yields two types: all MI Conditions for people who are Male, and all office visit Procedures for people who are Male",
              [ "person_filter", { left: [ "union", [ "icd9", "412" ], [ "cpt", "99214" ] ], right: [ "gender", "Male" ] } ]
      default_query_columns

      # PersonFilter has no `as` option, and a statement that sets one fails
      # validation instead of running as a plain person_filter (bead
      # conceptql-dlq).
      unsupported_options :as

      def query(db)
        db.from(left.evaluate(db))
          .where(person_id: right.evaluate(db).from_self.select_group(:person_id))
      end
    end
  end
end
