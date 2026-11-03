# frozen_string_literal: true

require_relative "../../../helper"
require_relative "../../../db_helper"
require "conceptql"

describe "ConceptQL Spec" do
  # The spec (ConceptQL.spec_path) links every operator as [Name](#name-operator).
  def self.spec
    @spec ||= ConceptQL.spec_path.read
  end

  def self.known_ids
    @known_ids ||= spec.scan(/\]\(#([^)\s]*operator)\)/).flatten.uniq
  end

  # GitHub's anchor for each heading outside a fence: the heading text in lower
  # case, without punctuation, with a hyphen for each space.
  def self.heading_anchors
    fence = false
    spec.each_line.filter_map do |line|
      fence = !fence if line.start_with?("```")
      next if fence || !line.match?(/\A#+ /)

      line.sub(/\A#+ /, "").strip.downcase.gsub(/[^\p{Word}\- ]/u, "").tr(" ", "-")
    end
  end

  known_operators = ConceptQL.metadata(CDB)[:operators]
                             .values
                             .map { |operator_metadata| operator_metadata[:spec_id] }
                             .uniq

  known_operators.each do |spec_id|
    it "should have #{spec_id} published in ConceptQL Spec" do
      _(self.class.known_ids.include?(spec_id)).must_equal(true, "#{spec_id} is not present in the ConceptQL Spec")
    end
  end

  it "should not include operators not present in ConceptQL" do
    _((self.class.known_ids - known_operators).uniq).must_be_empty("ConceptQL Spec contains operator descriptions for operators not present in ConceptQL")
  end

  it "has a heading for each anchor it links" do
    links = self.class.spec.scan(/\]\(#([^)\s]*)\)/).flatten.uniq

    _(links).wont_be_empty
    _(links - self.class.heading_anchors).must_be_empty
  end
end
