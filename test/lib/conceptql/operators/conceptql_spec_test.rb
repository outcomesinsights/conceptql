require_relative "../../../helper"
require "conceptql"
require "nokogiri"
require "open-uri"

describe "ConceptQL Spec" do
  $known_ids ||= Nokogiri::HTML(
      URI.open(
        ENV.fetch("CONCEPTQL_SPEC_URL", "https://github.com/outcomesinsights/conceptql_spec")
      )
    )
    .css("[href]")
    .map { |a| a.attr("href") }
    .select { |href| href =~ /^#/ && href =~ /operator$/ }
    .map { |href| href.sub("#", "") }
    .uniq

  $known_operators = ConceptQL.metadata[:operators]
    .values
    .map { |operator_metadata| operator_metadata[:spec_id] }
    .uniq

  $known_operators.each do |spec_id|
    it "should have #{spec_id} published in ConceptQL Spec" do
      _($known_ids.include?(spec_id)).must_equal(true, "#{spec_id} is not present in the ConceptQL Spec")
    end
  end

  it "should not include operators not present in ConceptQL" do
    _(($known_ids - $known_operators).uniq).must_be_empty("ConceptQL Spec contains operator descriptions for operators not present in ConceptQL")
  end

end