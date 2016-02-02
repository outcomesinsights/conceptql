require_relative 'helper'
require 'conceptql/knitter'

describe ConceptQL::Knitter do
  after do
    (Dir['test/knitter/.[0-9a-f]*/*'] + Dir['test/knitter/*.md'] + Dir['test/knitter/*/*.png']).each{|f| File.delete(f)}
    (Dir['test/knitter/*'] + Dir['test/knitter/.[0-9a-f]*']).each{|f| Dir.rmdir(f) if File.directory?(f) && Dir.new(f).entries == ['.', '..']}
  end

  def knit(example)
    ConceptQL::Knitter.new(CDB, "test/knitter/#{example}.md.cql").knit
    File.read("test/knitter/#{example}.md")
  end

  def silence
    ConceptQL::Knitter::ConceptQLChunk.send(:define_method, :puts){|*|}
    yield
  ensure
    ConceptQL::Knitter::ConceptQLChunk.send(:undef_method, :puts) 
  end

  it "returns values without ```ConceptQL as is" do
    knit('empty').must_equal ''
    knit('no_conceptql').must_equal File.read("test/knitter/no_conceptql.md.cql")
  end

  it "replaces ```ConceptQL with diagrams" do
    # Also test cache
    2.times do
      knit('conceptql').must_equal File.read("test/knitter/conceptql.md.expect")
    end
  end

  it "handles titles and no results" do
    2.times do
      knit('title').must_equal File.read("test/knitter/title.md.expect")
    end
  end

  it "handles bad statements using fake annotater" do
    silence do
      2.times do
        knit('fake').must_equal File.read("test/knitter/fake.md.expect")
      end
    end
  end
end
