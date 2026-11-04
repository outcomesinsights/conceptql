# frozen_string_literal: true

# The tests of ConceptQL::DiagramRenderer: `just test-diagram` runs this file.
# They need resvg and no database, so test/all.rb leaves them out.
Dir[File.join(__dir__, "**", "*_test.rb")].sort.each do |f|
  require f
end
