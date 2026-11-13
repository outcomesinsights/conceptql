# frozen_string_literal: true

require_relative "../behaviors/labish"

module ConceptQL
  module Vocabularies
    # The read operator: the vocabulary operator of the Read vocabulary (NHS UK
    # Read Codes Version 2), built from its row of config/vocabularies.csv like
    # every other vocabulary operator (bead conceptql-qdn9). Before, read was
    # an operator class that wrapped one Vocabulary operator, so it got no
    # vocabulary check. This module keeps the three things that the row
    # cannot say: the preferred name READ, read's own description, and the
    # lab columns (Labish). A Read code can carry a test result, so read
    # selects the value columns although its domain is condition_occurrence.
    #
    # Read codes are case-sensitive: "13g4.00" (Born in Burkina Faso) and
    # "13G4.00" (Social worker involved) are two codes. Every vocabulary
    # operator compares codes case-exactly, so a code in another case selects
    # nothing and is an unknown code.
    module ReadCodes
      OPERATOR = "read"
      PREFERRED_NAME = "READ"
      DESC = "Selects results based on the Read vocabulary."

      # The entry of read: the entry of the Read vocabulary with the preferred
      # name READ, as id => Entry. Without a Read entry there is none.
      def self.entries(read_entry)
        return {} unless read_entry

        { OPERATOR => read_entry.merge(Entry.new(id: read_entry.omopv5_id, preferred_name: PREFERRED_NAME)) }
      end

      # The behavior of the read operator class
      module OperatorBehavior
        def self.included(base)
          base.desc DESC
          base.include ConceptQL::Behaviors::Labish
        end
      end
    end
  end
end
