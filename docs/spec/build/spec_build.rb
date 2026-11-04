# frozen_string_literal: true

require "bigdecimal"
require "digest"
require "fileutils"
require "json"
require "tmpdir"
require_relative "reference"
require_relative "../../../test/prettier_json"

# Builds docs/spec/README.md from docs/spec/README.cql.md. First each
# directive of the source becomes its generated markdown (SpecBuild::Reference):
# the operator reference sections, the label option and Appendix E. Then each
# ```ConceptQL block becomes an example: the statement as JSON, its diagram
# (images/<name>.svg, drawn by ConceptQL::DiagramRenderer) and the first 10
# rows of its result. Last, the examples
# of each published spec_id go to examples/<spec_id>.json, with their rows and
# diagram trees. `just spec` runs docs/spec/build/run.rb, which calls this, on
# the DuckDB fixture.
module SpecBuild
  DIR = File.expand_path("..", __dir__)
  SOURCE = File.join(DIR, "README.cql.md")
  OUTPUT = File.join(DIR, "README.md")
  IMAGES = File.join(DIR, "images")
  MANIFEST = File.join(IMAGES, "manifest.tsv")
  # One JSON file of example results and diagram trees for each published
  # spec_id (ConceptQL.spec_examples_path)
  EXAMPLES = File.join(DIR, "examples")

  # Every result is ordered completely before the limit, so each run shows the
  # same rows (a criterion_id is unique only within its criterion_table).
  ORDER = %i[person_id criterion_domain start_date criterion_table criterion_id].freeze
  LIMIT = 10
  RESULT_KEYS = %i[person_id criterion_id criterion_table criterion_domain start_date end_date source_value].freeze

  # A ```ConceptQL block: `#` comment lines (its title) and one JSON statement.
  # ```ConceptQL{all_keys: true} shows every column of the result. +line+ is
  # the line in +lines+, and +origin+ names the place in README.cql.md.
  Block = Struct.new(:number, :line, :origin, :title, :statement, :all_keys, keyword_init: true)

  class << self
    # The ```ConceptQL blocks of +lines+. +origins+ names the place of each
    # line in README.cql.md.
    def blocks(lines, origins = lines.each_index.map { |i| "README.cql.md:#{i + 1}" })
      numbered = lines.each_with_index.select { |line, _| line.start_with?("```ConceptQL") }
      numbered.each_with_index.map do |(line, i), n|
        body = lines[(i + 1)..].take_while { |l| !l.start_with?("```") }
        titles, statement = body.partition { |l| l.match?(/\A\s*#/) }
        Block.new(number: n + 1, line: i + 1, origin: origins.fetch(i), all_keys: line.include?("all_keys: true"),
                  title: titles.map { |l| l.sub(/\A\s*#+\s*/, "").strip }.join(" "),
                  statement: JSON.parse(statement.join))
      end
    end

    # The JSON of +obj+ with string keys, every hash sorted by key. It names the
    # images and identifies the diagram trees. Ruby's inspect is not used, because
    # Hash#inspect changed in Ruby 3.4.
    def canonical_json(obj)
      JSON.generate(canonical(obj))
    end

    def sha(obj)
      Digest::SHA256.hexdigest(canonical_json(obj))
    end

    def image_name(statement)
      "#{sha(statement)}.svg"
    end

    # The images that do not match +trees+ (image name => diagram tree):
    # image name => "MISSING" when the file is not in +dir+, "stale" when the
    # manifest (the text of manifest.tsv) has no hash or another hash for it,
    # and "unused" for an SVG file in +dir+ that no tree names.
    def outdated(trees, manifest, dir = IMAGES)
      drawn = manifest.lines.to_h { |line| line.chomp.split("\t", 2) }
      unused = Dir[File.join(dir, "*.svg")].map { |f| File.basename(f) } - trees.keys
      trees.filter_map do |name, tree|
        if !File.file?(File.join(dir, name)) then [ name, "MISSING" ]
        elsif drawn[name] != sha(tree) then [ name, "stale" ]
        end
      end.to_h.merge(unused.sort.to_h { |name| [ name, "unused" ] })
    end

    def canonical(obj)
      case obj
      when Hash then obj.map { |k, v| [ k.to_s, canonical(v) ] }.sort_by(&:first).to_h
      when Array then obj.map { |v| canonical(v) }
      else obj
      end
    end
  end

  # Runs the examples against +db+ and +cdb+, and writes the output.
  class Build
    attr_reader :db, :cdb

    # +reference+ (a SpecBuild::Reference) writes the generated markdown.
    # With check: true (`just spec-check`) it draws the images into a
    # temporary directory and leaves IMAGES alone. It fails after it writes the
    # output when a committed image differs from its new drawing, or is
    # missing, stale or unused (SpecBuild.outdated).
    def initialize(db, cdb, reference:, check: false)
      @db = db
      @cdb = cdb
      @reference = reference
      @check = check
    end

    def run
      expanded = @reference.expand(File.readlines(SOURCE))
      lines = expanded.map(&:text)
      blocks = SpecBuild.blocks(lines, expanded.map(&:origin))
      results = blocks.to_h { |b| [ SpecBuild.sha(b.statement), result(b) ] }
      trees = blocks.to_h { |b| [ SpecBuild.image_name(b.statement), tree(b) ] }
      outdated = @check ? check_images(trees) : draw_images(trees)
      File.write(OUTPUT, knit(lines, blocks.to_h { |b| [ b.line, example(b, results.fetch(SpecBuild.sha(b.statement))) ] }))
      puts "wrote #{OUTPUT} (#{blocks.size} examples)"
      write_examples(results, trees)
      return unless @check && outdated.any?

      abort(<<~MSG)
        These images do not match the code (#{outdated.size}):
        #{outdated.map { |name, state| "  #{state} images/#{name}" }.join("\n")}
        Redraw them: run `just spec`, and commit what it changes.
      MSG
    end

    private

    # The first LIMIT rows of the result of one example
    def result(block)
      errors = cdb.query(block.statement).validation_errors
      raise "example #{block.number} (#{block.origin}) is not valid: #{errors}" unless errors.empty?

      ds = db.from(cdb.query(block.statement).query)
      rows = ds.order(*ORDER).limit(LIMIT).all
      puts format("[%02d] %-24s rows=%-6d %s", block.number, block.origin[/\A\S+/], ds.count, block.title[0, 70])
      rows
    end

    # The markdown of one example, with the +rows+ of its result
    def example(block, rows)
      heading = [ "**Example #{block.number}", block.title.empty? ? nil : block.title ].compact.join(" - ")
      [ "---", "#{heading}**", "```JSON\n#{JSON.generate(block.statement)}\n```",
        "![#{block.title.delete('[]')}](images/#{SpecBuild.image_name(block.statement)})",
        table(rows, block.all_keys), "---" ].join("\n\n")
    end

    # An empty result is plain text: a line that starts with ``` would open a
    # fence for every reader that splits the spec into sections.
    def table(rows, all_keys)
      return "No results." if rows.empty?

      keys = all_keys ? rows.first.keys : RESULT_KEYS
      [ keys, keys.map { |k| "-" * k.length } ].concat(rows.map { |r| r.values_at(*keys).map { |v| cell(v) } })
                                                 .map { |cols| "| #{cols.join(' | ')} |" }.join("\n")
    end

    def cell(value)
      text = value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
      text.gsub("|", "\\|")
    end

    # Draws each diagram tree of +trees+ (image name => tree, with its counts)
    # into IMAGES, removes the SVG files that no tree names, and writes
    # MANIFEST. It returns {}: no image is left that does not match.
    def draw_images(trees)
      FileUtils.mkdir_p(IMAGES)
      trees.each { |name, tree| draw(tree, File.join(IMAGES, name)) }
      stale = Dir[File.join(IMAGES, "*.svg")].reject { |f| trees.key?(File.basename(f)) }
      FileUtils.rm(stale)
      File.write(MANIFEST, trees.sort.map { |name, tree| "#{name}\t#{SpecBuild.sha(tree)}\n" }.join)
      puts "images: #{trees.size} drawn, #{stale.size} stale removed, #{MANIFEST} written"
      {}
    end

    # spec-check: draws each tree into a temporary directory and compares the
    # drawing with the committed image, byte for byte. It returns the images
    # that do not match: SpecBuild.outdated, plus "differs" for each committed
    # image whose new drawing is another file.
    def check_images(trees)
      manifest = File.file?(MANIFEST) ? File.read(MANIFEST) : ""
      outdated = SpecBuild.outdated(trees, manifest)
      Dir.mktmpdir("conceptql-spec-images") do |dir|
        trees.each do |name, tree|
          committed = File.join(IMAGES, name)
          next unless File.file?(committed)

          drawn = File.join(dir, name)
          draw(tree, drawn)
          outdated[name] ||= "differs" unless FileUtils.identical?(committed, drawn)
        end
      end
      puts "images: #{trees.size} drawn in a temporary directory, #{outdated.size} do not match images/"
      outdated
    end

    def tree(block)
      tree = ConceptQL::Diagram.render([ block.statement ], cdb: cdb, counts: true)
      tree[:statements].each { |node| check_counts(node, block) }
      tree
    end

    def check_counts(node, block)
      raise "example #{block.number} (#{block.origin}): no counts for #{node[:name]}" if node[:counts].blank?

      node[:children].each { |child| check_counts(child, block) }
    end

    # The static SVG of +tree+ (ConceptQL::DiagramRenderer.render_static), with
    # the counts on each stream and the options of each operator. It goes to a
    # temporary file beside +path+ first, and only a finished drawing replaces
    # +path+.
    def draw(tree, path)
      tmp = File.join(File.dirname(path), ".#{Process.pid}.#{File.basename(path)}")
      File.write(tmp, ConceptQL::DiagramRenderer.render_static(tree, show_counts: true, show_options: true))
      File.rename(tmp, path)
    ensure
      FileUtils.rm_f(tmp)
    end

    # Writes EXAMPLES/<spec_id>.json for each published spec_id: the examples
    # of its section, each with the rows of its result (in the columns of the
    # spec's tables) and its diagram tree, the tree that manifest.tsv hashes.
    # A file of a spec_id that is no longer published is removed.
    def write_examples(results, trees)
      FileUtils.mkdir_p(EXAMPLES)
      written = @reference.spec_ids.sort.map do |spec_id|
        examples = @reference.section_examples(spec_id).map { |example| example_entry(example, results, trees) }
        path = File.join(EXAMPLES, "#{spec_id}.json")
        File.write(path, PrettierJson.generate({ spec_id: spec_id, examples: examples }))
        path
      end
      stale = Dir[File.join(EXAMPLES, "*.json")] - written
      FileUtils.rm(stale)
      puts "examples: #{written.size} written, #{stale.size} stale removed, #{EXAMPLES}"
    end

    def example_entry(example, results, trees)
      statement = example.fetch(:statement)
      rows = results.fetch(SpecBuild.sha(statement)).map { |row| row.values_at(*RESULT_KEYS).map { |v| json_value(v) } }
      { title: example.fetch(:title), statement: statement, help: example.fetch(:help),
        columns: RESULT_KEYS, rows: rows, tree: trees.fetch(SpecBuild.image_name(statement)) }
    end

    def json_value(value)
      case value
      when Date then value.iso8601
      when BigDecimal then value.to_s("F")
      else value
      end
    end

    def knit(lines, examples)
      out = [ "<!-- just spec writes this file from README.cql.md. Edit README.cql.md, not this file. -->\n\n" ]
      skip = false
      lines.each_with_index do |line, i|
        if skip
          skip = false if line.start_with?("```")
        elsif examples.key?(i + 1)
          skip = true
          out << "#{examples.fetch(i + 1)}\n"
        else
          out << line
        end
      end
      out.join
    end
  end
end
