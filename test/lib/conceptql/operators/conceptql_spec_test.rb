# frozen_string_literal: true

require_relative '../../../helper'
require_relative '../../../db_helper'
require 'conceptql'
require 'net/http'

describe 'ConceptQL Spec' do
  # The spec's README links every operator from its table of contents as
  # [Name](#name-operator). Fetched on first use, not at require time.
  # CONCEPTQL_SPEC_README=<path> reads a local checkout instead of GitHub.
  def self.known_ids
    @known_ids ||= readme.scan(/\]\(#([^)\s]*operator)\)/).flatten.uniq
  end

  def self.readme
    return File.read(ENV.fetch('CONCEPTQL_SPEC_README')) if ENV.key?('CONCEPTQL_SPEC_README')

    url = ENV.fetch('CONCEPTQL_SPEC_URL',
                    'https://raw.githubusercontent.com/outcomesinsights/conceptql_spec/main/README.md')
    Net::HTTP.get_response(URI(url)).tap(&:value).body
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

  it 'should not include operators not present in ConceptQL' do
    _((self.class.known_ids - known_operators).uniq).must_be_empty('ConceptQL Spec contains operator descriptions for operators not present in ConceptQL')
  end
end
