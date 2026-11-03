# frozen_string_literal: true

require "bigdecimal"
require "digest"
require "fileutils"
require "json"
require "open3"

# Builds docs/spec/README.md from docs/spec/README.cql.md. Each ```ConceptQL
# block of the source becomes an example: the statement as JSON, its diagram
# (images/<name>.svg) and the first 10 rows of its result. `just spec` runs
# docs/spec/build/run.rb, which calls this, on the DuckDB fixture.
module SpecBuild
  DIR = File.expand_path("..", __dir__)
  SOURCE = File.join(DIR, "README.cql.md")
  OUTPUT = File.join(DIR, "README.md")
  IMAGES = File.join(DIR, "images")
  MANIFEST = File.join(IMAGES, "manifest.tsv")

  CLI_ENV = "CONCEPTQL_DIAGRAM_CLI"
  CLI_FLAGS = %w[--show-counts --show-options].freeze

  # Every result is ordered completely before the limit, so each run shows the
  # same rows (a criterion_id is unique only within its criterion_table).
  ORDER = %i[person_id criterion_domain start_date criterion_table criterion_id].freeze
  LIMIT = 10
  RESULT_KEYS = %i[person_id criterion_id criterion_table criterion_domain start_date end_date source_value].freeze

  # A ```ConceptQL block: `#` comment lines (its title) and one JSON statement.
  # ```ConceptQL{all_keys: true} shows every column of the result.
  Block = Struct.new(:number, :line, :title, :statement, :all_keys, keyword_init: true)

  class << self
    def blocks(lines)
      numbered = lines.each_with_index.select { |line, _| line.start_with?("```ConceptQL") }
      numbered.each_with_index.map do |(line, i), n|
        body = lines[(i + 1)..].take_while { |l| !l.start_with?("```") }
        titles, statement = body.partition { |l| l.match?(/\A\s*#/) }
        Block.new(number: n + 1, line: i + 1, all_keys: line.include?("all_keys: true"),
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

    # The images in +trees+ (image name => diagram tree) that are not current:
    # image name => "MISSING" when the file is not in +dir+, "stale" when the
    # manifest (the text of manifest.tsv) has no hash or another hash for it.
    def outdated(trees, manifest, dir = IMAGES)
      drawn = manifest.lines.to_h { |line| line.chomp.split("\t", 2) }
      trees.filter_map do |name, tree|
        if !File.file?(File.join(dir, name)) then [ name, "MISSING" ]
        elsif drawn[name] != sha(tree) then [ name, "stale" ]
        end
      end.to_h
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

    # With check: true (`just spec-check`) it never draws, and it fails after
    # it writes the output when an image is missing or stale.
    def initialize(db, cdb, check: false)
      @db = db
      @cdb = cdb
      @check = check
      @cli = check ? "" : ENV.fetch(CLI_ENV, "")
      raise "#{CLI_ENV}=#{@cli} is not a file" unless @cli.empty? || File.file?(@cli)
    end

    def run
      lines = File.readlines(SOURCE)
      blocks = SpecBuild.blocks(lines)
      examples = blocks.to_h { |b| [ b.line, example(b) ] }
      outdated = images(blocks)
      File.write(OUTPUT, knit(lines, examples))
      puts "wrote #{OUTPUT} (#{blocks.size} examples)"
      return unless @check && outdated.any?

      abort(<<~MSG)
        These images do not show the current diagram tree (#{outdated.size}):
        #{outdated.map { |name, state| "  #{state} images/#{name}" }.join("\n")}
        Redraw them: run `just spec` with #{CLI_ENV} set to the renderer CLI.
      MSG
    end

    private

    def draw?
      !@cli.empty?
    end

    # The markdown of one example.
    def example(block)
      errors = cdb.query(block.statement).validation_errors
      raise "example #{block.number} (README.cql.md:#{block.line}) is not valid: #{errors}" unless errors.empty?

      ds = db.from(cdb.query(block.statement).query)
      rows = ds.order(*ORDER).limit(LIMIT).all
      puts format("[%02d] line %4d rows=%-6d %s", block.number, block.line, ds.count, block.title[0, 70])
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

    # Each diagram tree, with its counts, as the renderer draws it. Without the
    # renderer the committed images stay: nothing is deleted and nothing fails.
    # It returns the images that are missing or stale (SpecBuild.outdated).
    def images(blocks)
      trees = blocks.to_h { |b| [ SpecBuild.image_name(b.statement), tree(b) ] }
      unless draw?
        manifest = File.file?(MANIFEST) ? File.read(MANIFEST) : ""
        outdated = SpecBuild.outdated(trees, manifest)
        trees.each_key do |name|
          puts "not drawn (#{CLI_ENV} is not set, #{outdated.fetch(name, 'kept')}): images/#{name}"
        end
        return outdated
      end

      FileUtils.mkdir_p(IMAGES)
      trees.each { |name, tree| draw(tree, File.join(IMAGES, name)) }
      stale = Dir[File.join(IMAGES, "*.svg")].reject { |f| trees.key?(File.basename(f)) }
      FileUtils.rm(stale)
      File.write(MANIFEST, trees.sort.map { |name, tree| "#{name}\t#{SpecBuild.sha(tree)}\n" }.join)
      puts "images: #{trees.size} drawn, #{stale.size} stale removed, #{MANIFEST} written"
      {}
    end

    def tree(block)
      tree = ConceptQL::Diagram.render([ block.statement ], cdb: cdb, counts: true)
      tree[:statements].each { |node| check_counts(node, block) }
      tree
    end

    def check_counts(node, block)
      raise "example #{block.number} (README.cql.md:#{block.line}): no counts for #{node[:name]}" if node[:counts].blank?

      node[:children].each { |child| check_counts(child, block) }
    end

    # The renderer writes a temporary file beside +path+, and only a finished
    # drawing replaces +path+. The renderer picks the format by the extension.
    def draw(tree, path)
      tmp = File.join(File.dirname(path), ".#{Process.pid}.#{File.basename(path)}")
      _out, err, status = Open3.capture3("node", @cli, "render", "-", "-o", tmp, *CLI_FLAGS,
                                         stdin_data: JSON.generate(tree))
      raise "conceptql-diagram failed for #{path} (#{status}):\n#{err}" unless status.success?

      File.rename(tmp, path)
    ensure
      FileUtils.rm_f(tmp)
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
