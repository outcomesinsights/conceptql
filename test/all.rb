# frozen_string_literal: true

# test/diagram_renderer/ needs the resvg program, which the Postgres docker
# image and the DuckDB runs do not have: `just test-diagram` runs it
# (test/diagram_renderer/all.rb).
Dir["./test/**/*_test.rb"].sort.each do |f|
  next if f.start_with?("./test/diagram_renderer/")

  require f
end
