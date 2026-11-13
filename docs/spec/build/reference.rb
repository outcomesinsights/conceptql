# frozen_string_literal: true

require "json"

module SpecBuild
  # Writes the operator reference of the spec from ConceptQL.metadata, so the
  # texts in the operator classes are the only copy (bead conceptql-jwsv.10).
  # README.cql.md marks the place of each generated block with a directive, a
  # line of its own:
  #
  #   <!-- conceptql-spec: operator SPEC_ID -->       the reference section of SPEC_ID
  #   <!-- conceptql-spec: label-option -->           the text of the label option
  #   <!-- conceptql-spec: quick-reference -->        Appendix E, one row per spec_id
  #   <!-- conceptql-spec: vocabulary-operators -->   one row per vocabulary operator
  #
  # An operator directive comes directly after the heading of its section, and
  # the anchor of that heading is the spec_id. Each published spec_id has one
  # operator directive, and the other directives appear once each. Without a
  # published vocabulary operator, the vocabulary-operators directive must not
  # appear.
  class Reference
    DIRECTIVE = /\A<!-- conceptql-spec: (?<kind>[a-z-]+)(?: (?<arg>\S+))? -->\s*\z/
    KINDS = %w[operator label-option quick-reference vocabulary-operators].freeze
    SINGLE_KINDS = KINDS - %w[operator]

    # The upstreams facet as text. A "left_right" operator takes its operands
    # as options, so its section has no upstream line.
    UPSTREAMS = {
      "none" => "none",
      "none_or_one" => "none, or one operator",
      "one" => "one operator",
      "one_or_more" => "one or more operators",
      "two_or_more" => "two or more operators"
    }.freeze

    # The options that hold the left-hand and the right-hand stream. The
    # section shows them as the operator's operands.
    OPERANDS = %i[left right].freeze

    # The vocabulary operators share one section, and each one has its own
    # desc. The section shows the desc of the class that holds their shared
    # texts (Vocabulary::SharedDocumentation).
    SHARED_SECTION = "vocabulary-operator"

    # The class terms of the spec that have a rule: the facets that every
    # operator of the class has (bead conceptql-tc0q). The spec puts an
    # operator in a class with the "## " heading of its section, or with a
    # sentence "It is a [term](...)" in its section. A term without a rule is
    # not checked: "set operator" (union and except share no facet) and
    # "relative temporal operator" (its facets equal an inline filter's).
    ClassTerm = Struct.new(:rule, :facets, :test)
    CLASS_TERMS = {
      "selection operator" =>
        ClassTerm.new('effects includes "select"', %i[effects], ->(op) { op.fetch(:effects).include?("select") }),
      "temporal comparison operator" =>
        ClassTerm.new("temporal_comparison is true", %i[temporal_comparison], ->(op) { op.fetch(:temporal_comparison) == true }),
      "time manipulation operator" =>
        ClassTerm.new('effects includes "change"', %i[effects], ->(op) { op.fetch(:effects).include?("change") }),
      "inline filter operator" =>
        ClassTerm.new('upstreams is "one" and effects includes "keep"', %i[upstreams effects],
                      ->(op) { op.fetch(:upstreams) == "one" && op.fetch(:effects).include?("keep") }),
      "comparison operator" =>
        ClassTerm.new('upstreams is "left_right" or "two_or_more", and effects includes "keep"', %i[upstreams effects],
                      ->(op) { %w[left_right two_or_more].include?(op.fetch(:upstreams)) && op.fetch(:effects).include?("keep") })
    }.freeze

    # The "## " headings that put the operators of their sections in a class
    HEADING_TERMS = {
      "Selection Operators" => "selection operator",
      "`Vocabulary` Operator" => "selection operator",
      "Other Selection Operators" => "selection operator",
      "Temporal Comparison Operators" => "temporal comparison operator",
      "Time Manipulation Operators" => "time manipulation operator",
      "Inline-Filter Operators" => "inline filter operator",
      "Comparison Operators" => "comparison operator"
    }.freeze

    # A sentence that puts the operator of its section in a class
    CLAIM = /It is an? \[([^\]]+)\]\(/

    # One line of the expanded source and the place it came from
    Line = Struct.new(:text, :origin)

    # +metadata+ is ConceptQL.metadata of the database that decides which
    # operators are published: Database.new(nil, data_model: :gdm) with no
    # custom vocabularies.
    def initialize(metadata, source: "README.cql.md")
      @source = source
      @operators = metadata[:operators].values
      @priorities = metadata[:categories].to_h { |category| [ category[:name], category[:priority] ] }
      @sections = @operators.group_by { |operator| operator[:spec_id] }
    end

    # The published spec_ids
    def spec_ids
      @sections.keys
    end

    # +lines+ (README.cql.md) with each directive replaced by its markdown,
    # as Lines. A directive that is unknown, misplaced, missing or repeated
    # raises.
    def expand(lines)
      headings = check(lines)
      lines.each_with_index.flat_map do |line, i|
        origin = "#{@source}:#{i + 1}"
        directive = DIRECTIVE.match(line)
        next [ Line.new(line, origin) ] unless directive

        markdown(directive, headings).lines.map { |text| Line.new(text, "#{origin} (#{directive[0].strip})") }
      end
    end

    # The markdown of the reference section of +spec_id+, in a fixed order:
    # the desc, the upstream operators or the operands, the arguments, the
    # options, the returns text and the examples. Every operator takes the
    # label option, so a section does not list it.
    def section(spec_id)
      operator = @sections.fetch(spec_id).first
      operands, options = operator[:options].except(:label).partition { |name, _| OPERANDS.include?(name) }
      items = []
      items << upstream(operator) unless operator[:upstreams] == "left_right"
      items << list("Operands", operands) if operands.any?
      items << list("Arguments", operator[:arguments]) if operator[:arguments].any?
      items << list("Options", options) if options.any?
      items << "- **Returns:** #{operator.fetch(:returns)}"
      [ desc(spec_id), items.join("\n"), *examples(spec_id) ].join("\n\n") + "\n"
    end

    # The text of the label option, which every published operator shares
    def label_option
      texts = @operators.map { |operator| operator[:options].fetch(:label).fetch(:meaning) }.uniq
      raise "the label option has #{texts.size} different texts, not one" unless texts.one?

      "#{texts.first}\n"
    end

    # Appendix E: one row for each published spec_id, ordered by category and
    # then by the place of its section. +headings+ maps each spec_id to the
    # text of its section's heading.
    def quick_reference(headings)
      rows = headings.keys.each_with_index.sort_by { |spec_id, i| [ @priorities.fetch(category(spec_id)), i ] }
      [ "| Operator | Jigsaw category | What it does |", "| --- | --- | --- |",
        *rows.map { |spec_id, _| "| #{link(spec_id, headings)} | #{category(spec_id)} | #{cell(desc(spec_id))} |" } ]
        .join("\n") + "\n"
    end

    # The table of the vocabulary operators: one row for each published
    # operator of the shared section, ordered by name, with its full
    # vocabulary name (long_name) and its domains. A deprecated operator is
    # marked. An operator without a long_name or a domain raises.
    def vocabulary_operators
      rows = @sections.fetch(SHARED_SECTION).sort_by { |operator| operator[:name] }.map do |operator|
        long_name = operator[:long_name].to_s
        domains = operator[:predominant_domains].to_a
        raise "the vocabulary operator #{operator[:name]} has no long_name" if long_name.strip.empty?
        raise "the vocabulary operator #{operator[:name]} has no domain" if domains.empty?

        name = "`#{operator[:name]}`#{' (deprecated)' if operator[:deprecated]}"
        "| #{name} | #{cell(long_name)} | #{domains.join(', ')} |"
      end
      [ "| Operator | Vocabulary | Domain |", "| --- | --- | --- |", *rows ].join("\n") + "\n"
    end

    # The desc of the section. Operators of one spec_id have one desc, except
    # the vocabulary operators.
    def desc(spec_id)
      descs = @sections.fetch(spec_id).map { |operator| operator[:desc] }.uniq
      return descs.first if descs.one?
      raise "the operators of #{spec_id} have #{descs.size} different descs" unless spec_id == SHARED_SECTION

      ConceptQL::Operators::Vocabulary.desc
    end

    # The examples ({title:, statement:, help:}) of every operator of the
    # section of +spec_id+, in the order of the section: the examples that an
    # editor shows in its help come first.
    def section_examples(spec_id)
      @sections.fetch(spec_id).flat_map { |operator| operator[:examples] }.partition { |example| example[:help] }.flatten(1)
    end

    private

    def markdown(directive, headings)
      case directive[:kind]
      when "operator" then section(directive[:arg])
      when "label-option" then label_option
      when "quick-reference" then quick_reference(headings)
      when "vocabulary-operators" then vocabulary_operators
      end
    end

    # Each directive is known and in place, and each published spec_id has a
    # section. Returns the heading text of each section, by spec_id, in the
    # order of the source.
    def check(lines)
      found = lines.each_with_index.filter_map { |line, i| [ DIRECTIVE.match(line), i ] if line.start_with?("<!-- conceptql-spec:") }
      errors = []
      headings = {}
      places = {}
      found.each do |directive, i|
        at = "#{@source}:#{i + 1}"
        if directive.nil? || !KINDS.include?(directive[:kind])
          errors << "#{at}: unknown directive #{lines[i].strip}"
        elsif directive[:kind] == "operator"
          spec_id = directive[:arg]
          heading = lines[0...i].reverse.find { |line| !line.strip.empty? }.to_s
          if !@sections.key?(spec_id) then errors << "#{at}: no published operator has the spec_id #{spec_id}"
          elsif headings.key?(spec_id) then errors << "#{at}: a second section of #{spec_id}"
          elsif anchor(heading) != spec_id then errors << "#{at}: the heading before the directive of #{spec_id} is not #{spec_id}: #{heading.strip}"
          else
            headings[spec_id] = heading.sub(/\A#+ /, "").strip
            places[i] = spec_id
          end
        end
      end
      SINGLE_KINDS.each do |kind|
        count = found.count { |directive, _| directive && directive[:kind] == kind }
        expected = kind == "vocabulary-operators" && !@sections.key?(SHARED_SECTION) ? 0 : 1
        errors << "#{@source}: #{count} #{kind} directives, not #{expected}" unless count == expected
      end
      missing = spec_ids - headings.keys
      errors << "#{@source}: no section for #{missing.join(', ')}" if missing.any?
      errors.concat(class_term_errors(lines, places))
      raise "The operator reference cannot be generated:\n#{errors.join("\n")}" if errors.any?

      headings
    end

    # Each operator meets the rule of the class term of its "## " heading
    # (HEADING_TERMS) and of each sentence "It is a [term](...)" in its
    # section. +places+ maps the line index of each operator directive to its
    # spec_id. A section ends at the next heading. Fenced lines are skipped.
    def class_term_errors(lines, places)
      errors = []
      fence = false
      heading = owner = nil
      lines.each_with_index do |line, i|
        fence = !fence if line.start_with?("```")
        next if fence || line.start_with?("```")

        at = "#{@source}:#{i + 1}"
        if line.match?(/\A#+ /)
          heading = line.sub(/\A#+ /, "").strip if line.match?(/\A##? /)
          owner = nil
        elsif places.key?(i)
          owner = places.fetch(i)
          errors.concat(term_errors(owner, HEADING_TERMS[heading], at, %(is under the heading "## #{heading}")))
        else
          line.scan(CLAIM) do
            claim = Regexp.last_match
            next unless CLASS_TERMS.key?(claim[1])

            place = %(says "#{claim[0].chomp('(')}")
            errors.concat(owner ? term_errors(owner, claim[1], at, place) : [ "#{at}: #{place} outside an operator section" ])
          end
        end
      end
      errors
    end

    # The operators of +spec_id+ that do not meet the rule of +term+, each as
    # an error that names the operator, the term, the rule and the facets
    def term_errors(spec_id, term, at, place)
      return [] unless term

      rule = CLASS_TERMS.fetch(term)
      @sections.fetch(spec_id).reject { |operator| rule.test.call(operator) }.map do |operator|
        facets = rule.facets.map { |key| "#{key} #{operator.fetch(key).inspect}" }.join(", ")
        %(#{at}: #{operator[:name]} #{place}, the term "#{term}", whose rule is: #{rule.rule}. Its facets: #{facets})
      end
    end

    # GitHub's anchor of a heading line: the text in lower case, without
    # punctuation, with a hyphen for each space. "" for a line that is not a heading.
    def anchor(line)
      return "" unless line.match?(/\A#+ /)

      line.sub(/\A#+ /, "").strip.downcase.gsub(/[^\p{Word}\- ]/u, "").tr(" ", "-")
    end

    def upstream(operator)
      "- **Upstream:** #{UPSTREAMS.fetch(operator[:upstreams])}."
    end

    def list(heading, params)
      [ "- **#{heading}:**", *params.map { |name, opt| "  - `#{name}`#{facts(opt)}: #{opt.fetch(:meaning)}" } ].join("\n")
    end

    # The type of a parameter, whether it is required, and the values that
    # it allows
    def facts(opt)
      values = "one of #{opt[:options].map { |value| "`#{value}`" }.join(', ')}" if opt[:options].is_a?(Array)
      facts = [ (opt[:type] unless opt[:type] == :upstream), ("required" if opt[:required]), values ].compact
      facts.empty? ? "" : " (#{facts.join(', ')})"
    end

    # The examples of every operator of the section as ConceptQL blocks
    def examples(spec_id)
      section_examples(spec_id).map do |example|
        "```ConceptQL\n# #{example.fetch(:title)}\n#{JSON.generate(example.fetch(:statement))}\n```"
      end
    end

    def category(spec_id)
      categories = @sections.fetch(spec_id).flat_map { |operator| operator[:categories].flatten }.uniq
      raise "the operators of #{spec_id} have the categories #{categories}, not one" unless categories.one?

      categories.first
    end

    def link(spec_id, headings)
      names = @sections.fetch(spec_id).map { |operator| operator[:name] }
      text = names.one? ? "`#{names.first}`" : headings.fetch(spec_id)
      "[#{text}](##{spec_id})"
    end

    def cell(text)
      text.gsub("|", "\\|")
    end
  end
end
