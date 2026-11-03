# frozen_string_literal: true

require_relative "binary_operator_operator"

module ConceptQL
  module Operators
    class PersonFilter < BinaryOperatorOperator
      register __FILE__

      desc "Keeps each left-hand record whose patient has at least one record in the right-hand stream. The type and the dates of the right-hand records do not matter."
      returns "The left-hand records of every type whose patient has at least one right-hand record. The right-hand records are not returned."
      option_meaning :right, "The right-hand stream. The operator keeps the left-hand records of each patient who has a record in this stream, and does not pass these records on."

      example "All MI Conditions for people who are male",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "gender", "Male" ] } ]
      example "All MI Conditions for people who had an office visit at some point in the data",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "cpt", "99214" ] } ]
      example "The same result as the example above, with the office visits converted to patients first",
              [ "person_filter", { left: [ "icd9", "412" ], right: [ "person", [ "cpt", "99214" ] ] } ]
      example "All MI Conditions for people who are Male OR had an office visit at some point in the data",
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
