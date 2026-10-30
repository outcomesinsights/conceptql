# frozen_string_literal: true

require_relative "../../helper"
require_relative "../../../script/spec/old_inspect"

# `just spec` names each diagram of doc/spec/ as the 2016 knitter did
# (script/spec/old_inspect.rb). The expected names are files that doc/spec/
# held before the 2026 rewrite, so they prove the Ruby 2.x inspect form.
# No database is needed.
describe OldInspect do
  statement = [ "person_filter", { "left" => [ "icd9", "412" ], "right" => [ "gender", "Male" ] } ]

  it "writes the Ruby 2.x inspect with symbol keys" do
    _(OldInspect.call(statement)).must_equal '["person_filter", {:left=>["icd9", "412"], :right=>["gender", "Male"]}]'
  end

  it "names a diagram with the SHA256 of that inspect" do
    _(OldInspect.sha(statement)).must_equal "0360fc0c2b7a88fd82ffc4d13387b76766649d5d42aa8f9349bbf60a81ac6119"
    _(OldInspect.sha([ "time_window", [ "icd9", "412" ], { "start" => "-2y", "end" => "-2y" } ]))
      .must_equal "15268bc45993d3f57ccf915877f91e48bdee684f24faa614249915833cac4af9"
    _(OldInspect.sha([ "numeric", 2, [ "icd9", "412" ] ]))
      .must_equal "d39452b58257c95a7cba07afed4877417b0c227f3690e2bff22c9eca89eac845"
  end
end
