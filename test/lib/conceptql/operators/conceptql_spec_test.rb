require_relative "../../../helper"
require "conceptql"
require "nokogiri"
require "watir"

describe "ConceptQL Spec" do
  $browser = Watir::Browser.new(:chrome, options: { args: %w(no-sandbox headless disable-dev-shm-usage disable-gpu disable-software-rasterizer) }) 
  $browser.goto(ENV.fetch("CONCEPTQL_SPEC_URL", "https://github.com/outcomesinsights/conceptql_spec"))
  $readme_doc = $browser.element(css: "article.markdown-body").wait_until(&:present?)
  $known_ids ||= Nokogiri::HTML($readme_doc.inner_html)
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