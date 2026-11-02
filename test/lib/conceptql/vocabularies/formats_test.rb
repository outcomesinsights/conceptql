# frozen_string_literal: true

require_relative "../../../helper"
require "csv"
require "tempfile"

# conceptql keeps no code-format regexps of its own. It reads the DEFAULT rows
# of config/vocabulary_formats.tsv, a pinned copy of the published table of
# outcomesinsights/vocabulary_formats (bead conceptql-bns, seed conceptql-ysx).
# `just vocabulary-formats <ref>` refreshes the copy and the recorded SHA.
describe ConceptQL::Vocabularies::Formats do
  let(:table) { CSV.read(ConceptQL.vocabulary_formats_file_path, col_sep: "\t", headers: true) }
  let(:formats) { ConceptQL::Vocabularies::Formats }
  let(:entries) { ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs }

  it "records the vocabulary_formats commit that the copy came from" do
    _(ConceptQL.vocabulary_formats_sha_file_path.read).must_match(/\A\h{40}\n\z/)
  end

  it "is in the files the gemspec ships" do
    gemspec = Gem::Specification.load(ConceptQL.root.join("conceptql.gemspec").to_s)

    _(gemspec.files).must_include "config/vocabulary_formats.tsv"
    _(gemspec.files).must_include "config/vocabulary_formats.sha"
  end

  it "anchors the DEFAULT row of a vocabulary as \\A(?:pattern)\\z" do
    row = table.find { |r| r["vocabulary_id"] == "ICD9CM" }

    _(formats.pattern("ICD9CM")).must_equal "\\A(?:#{row["regexp"]})\\z"
    _(formats.regexp("ICD9CM")).must_equal Regexp.new("\\A(?:#{row["regexp"]})\\z")
  end

  it "never uses a variant row" do
    _(formats.pattern("ICD9CM.DOTLESS")).must_be_nil
    _(formats.pattern("NDC")).must_equal "\\A(?:\\d{11})\\z"
  end

  it "looks a vocabulary up without regard to case" do
    _(formats.pattern("icd10pcs")).must_equal formats.pattern("ICD10PCS")
    _(formats.pattern("rxnorm extension")).wont_be_nil
  end

  it "has no pattern for a vocabulary without a row" do
    _(formats.pattern("LOINC")).must_be_nil
    _(formats.regexp("Gemscript")).must_be_nil
  end

  it "matches a whole code only, also across a newline" do
    icd10cm = formats.regexp("ICD10CM")

    _("I10").must_match icd10cm
    _("I10 and more").wont_match icd10cm
    _("I10\nI11").wont_match icd10cm
  end

  # A row is case-exact unless it declares case-insensitivity with the scoped
  # flag (?i:...) (vocabulary_formats seed vfm-8k1, conceptql seed
  # conceptql-oji ruling "b"). Formats adds no ignore-case flag of its own.
  describe "case" do
    include FormatsTable

    it "compiles a row case-exactly" do
      icd10cm = formats.regexp("ICD10CM")

      _(icd10cm.options & Regexp::IGNORECASE).must_equal 0
      _("I16.5").must_match icd10cm
      _("i16.5").wont_match icd10cm
      _(formats.case_insensitive?("ICD10CM")).must_equal false
    end

    it "accepts both cases where a row declares (?i:...), and only there" do
      with_formats_table("DECLARED" => "(?i:[A-Z])\\d{2}", "EXACT" => "[A-Z]\\d{2}") do
        _("A12").must_match formats.regexp("DECLARED")
        _("a12").must_match formats.regexp("DECLARED")
        _("A12").must_match formats.regexp("EXACT")
        _("a12").wont_match formats.regexp("EXACT")
        _(formats.case_insensitive?("declared")).must_equal true
        _(formats.case_insensitive?("EXACT")).must_equal false
        _(formats.case_insensitive?("NOROW")).must_equal false
      end
    end

    it "honors the scope of a (?i:...) group" do
      with_formats_table("PARTLY" => "(?i:[A-Z])[A-Z]") do
        _("aB").must_match formats.regexp("PARTLY")
        _("ab").wont_match formats.regexp("PARTLY")
      end
    end

    it "reads the pinned table again after a substitute table" do
      with_formats_table("ICD10CM" => "(?i:x)") { _(formats.pattern("ICD10CM")).must_equal "\\A(?:(?i:x))\\z" }

      _(formats.pattern("ICD10CM")).must_equal "\\A(?:#{table.find { |r| r["vocabulary_id"] == "ICD10CM" }["regexp"]})\\z"
    end
  end

  it "fills the format_regexp metadata of a vocabulary entry" do
    _(entries["icd9cm"].format_regexp).must_equal formats.pattern("ICD9CM")
    _(entries["icd10who"].format_regexp).must_equal formats.pattern("ICD10")
    _(entries["icd9cm"].to_hash[:format_regexp]).must_equal formats.pattern("ICD9CM")
    _(entries["loinc"].format_regexp).must_be_nil
  end

  it "is the only source of code formats" do
    _(CSV.read(ConceptQL.vocabularies_file_path, headers: true).headers).wont_include "format_regexp"
  end

  it "ignores a format_regexp column in a custom vocabularies file" do
    Tempfile.create([ "vocabularies", ".csv" ]) do |f|
      f.write("id,format_regexp\nLOINC,^nothing$\nICD9CM,^nothing$\n")
      f.flush
      ConceptQL.stub(:custom_vocabularies_file_path, Pathname.new(f.path)) do
        vocabs = ConceptQL::Vocabularies::DynamicVocabularies.new.all_vocabs

        _(vocabs["loinc"].format_regexp).must_be_nil
        _(vocabs["icd9cm"].format_regexp).must_equal formats.pattern("ICD9CM")
      end
    end
  end
end
