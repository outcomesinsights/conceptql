# frozen_string_literal: true

module ConceptQL
  module Metadatable
    # The facets of an operator: top-level keys of its metadata. The values of
    # the first seven come from the code (validations, behavior modules and
    # superclasses). Each operator declares its effects. docs/metadata.md
    # says what each one means. A reader that needs every facet iterates this
    # list.
    FACET_KEYS = %i[upstreams reads_data timeless takes_codes uses_provenance utilization temporal_comparison effects].freeze

    # What an operator can do to rows. docs/metadata.md says what each one
    # means.
    EFFECTS = %i[select keep change combine aggregate cast refer].freeze

    # Raised when an operator class declares an effect outside EFFECTS
    class UnknownEffectError < ArgumentError
      def initialize(klass, unknown)
        super("#{klass} declares unknown effects #{unknown.inspect}. The known effects are #{EFFECTS.inspect}.")
      end
    end

    def preferred_name(value = nil)
      return @preferred_name unless value

      @preferred_name = value
    end

    def aliases(value = nil)
      return @aliases unless value

      @aliases = value
    end

    def desc(value = nil)
      return @desc unless value

      @desc = value
    end

    def short_name(value = nil)
      return @short_name unless value

      @short_name = value
    end

    def long_name(value = nil)
      return @long_name unless value

      @long_name = value
    end

    def conceptql_spec_id(value = nil)
      return @conceptql_spec_id unless value

      @conceptql_spec_id = value
    end

    # Marks an operator as deprecated. It still runs. Operator#validate adds
    # the message to its annotation as a warning, and its metadata says
    # deprecated: true. A subclass does not inherit the mark.
    def deprecated(message = nil)
      return @deprecated unless message

      @deprecated = message
    end

    # Marks an operator as hidden. It still runs, but ConceptQL.metadata
    # (Nodifier#to_metadata) leaves it out, so an editor does not offer it.
    # An operator is not hidden unless it says so. A subclass does not
    # inherit the mark.
    def hidden
      @hidden = true
    end

    def hidden?
      @hidden || false
    end

    def predominant_domains(*values)
      return @predominant_domains if values.empty?

      @predominant_domains = values
    end

    # An argument or option can carry two texts. instructions: is the form
    # hint for typing a value. meaning: says what the argument or option
    # does. Both are plain text, because the diagram editor escapes them.
    def argument(name, options = {})
      (@arguments ||= [])
      @arguments << [ name, auto_label(name, options) ]
    end

    # The options that one argument was declared with
    def argument_options(name)
      (@arguments || []).to_h.fetch(name)
    end

    def option(name, options = {})
      @options ||= {}
      @options[name] = auto_label(name, options)
    end

    # Replaces the meaning: text of an option, usually one that this class
    # inherited. The option hash is shared with the parent class (see
    # #inherited), so this stores a copy and leaves the parent's text alone.
    # An option that the class does not have raises KeyError.
    def option_meaning(name, text)
      @options[name] = @options.fetch(name).merge(meaning: text)
    end

    # The plain text that says which records the operator returns. A
    # subclass does not inherit it.
    def returns(value = nil)
      return @returns unless value

      @returns = value
    end

    # Adds an example: a title and a ConceptQL statement. help: false keeps
    # the example out of an editor's help, for example because it returns no
    # rows on the test data. The spec build generates the results and the
    # diagram, so they are never written here. A subclass does not inherit
    # the examples, because they would show the wrong operator.
    def example(title, statement, help: true)
      (@examples ||= []) << { title: title, statement: statement, help: help }
    end

    def examples
      @examples || []
    end

    # Takes an option that a subclass inherited out of its metadata
    def remove_option(name)
      @options.delete(name)
    end

    def auto_label(name, opts = {})
      return opts if opts[:label]
      return opts.merge(label: name.to_s.split("_").map(&:capitalize).join(" ")) unless opts[:type] == :codelist

      opts.merge(label: "#{pref_name} Codes")
    end

    def domains(*domain_list)
      @domains = domain_list
      define_method(:domains) do |_db|
        domain_list
      end
      return unless domain_list.length == 1

      define_method(:domain) do
        domain_list.first
      end
    end

    # Declares what the operator does to rows, for example effects :keep,
    # :change. The metadata lists them in this order. Without values, gives
    # the declared effects (an empty list when there are none). A subclass
    # inherits them, so the vocabulary operators get the effects of
    # Vocabulary.
    def effects(*values)
      return @effects || [] if values.empty?

      unknown = values - EFFECTS
      raise UnknownEffectError.new(self, unknown) unless unknown.empty?

      @effects = values
    end

    # Declares the symbol that a diagram draws for the operator: :selection,
    # :filter, :set, :temporal or :cast. Only the drawing reads it, because
    # the facets cannot give it: count draws :set and episode draws
    # :temporal, and both take one upstream. A subclass inherits it.
    def diagram_base(value = nil)
      return @diagram_base unless value

      @diagram_base = value
    end

    # min_upstreams and max_upstreams say how many positional upstreams pass
    # validation (99 means no limit). A validate_*_upstream check sets them
    # again when to_metadata runs (derive_metadata_from_validations).
    def allows_many_upstreams
      @min_upstreams = 0
      @max_upstreams = 99
    end

    def allows_one_upstream
      @min_upstreams = 0
      @max_upstreams = 1
    end

    def just_class_name
      to_s.split("::").last
    end

    def humanized_class_name
      just_class_name.gsub(/([A-Z])/, ' \1').lstrip
    end

    def category(category)
      (@categories ||= [])
      @categories << Array(category)
    end

    def reset_categories
      @categories = []
    end

    def inherited(upstream)
      super
      (@options || {}).each do |name, opt|
        upstream.option name, opt
      end

      (@categories || []).each do |cat|
        upstream.category cat
      end

      upstream.diagram_base @diagram_base
      upstream.effects(*@effects) if @effects

      case @max_upstreams
      when 1
        upstream.allows_one_upstream
      when 99
        upstream.allows_many_upstreams
      end
    end

    def pref_name
      @preferred_name || humanized_class_name
    end

    def spec_id
      "#{@conceptql_spec_id || pref_name} operator".gsub(/\s+/, "-").downcase
    end

    def to_metadata(name, opts = {})
      derive_metadata_from_validations
      warn_about_missing_metadata if opts[:warn]
      {
        name: name,
        preferred_name: pref_name,
        short_name: short_name,
        long_name: long_name,
        operation: just_class_name.underscore,
        min_upstreams: @min_upstreams || 0,
        max_upstreams: @max_upstreams || 0,
        arguments: @arguments || [],
        options: process_options(@options),
        # Strings, as JSON gives them: domains (for example death) are symbols
        predominant_domains: (@domains || @predominant_domains || []).map(&:to_s),
        desc: get_desc,
        categories: @categories || [],
        basic_type: @diagram_base, # the old name of diagram_base
        diagram_base: @diagram_base,
        deprecated: (true if deprecated), # nil for an operator that is not deprecated
        arity: arity,
        aliases: @aliases,
        spec_id: spec_id,
        returns: get_returns,
        examples: examples_for(name)
      }.merge(facets)
    end

    # The value of each key in FACET_KEYS
    def facets
      {
        upstreams: upstreams_facet,
        reads_data: include?(ConceptQL::Behaviors::Windowable),
        timeless: include?(ConceptQL::Behaviors::Timeless),
        takes_codes: include?(ConceptQL::Behaviors::CodeLister),
        uses_provenance: include?(ConceptQL::Provenanceable),
        utilization: include?(ConceptQL::Behaviors::Utilizable),
        temporal_comparison: ancestors.include?(ConceptQL::Operators::TemporalOperator),
        effects: effects.map(&:to_s)
      }
    end

    # The upstreams that the validations accept, as one word. The first
    # check that matches wins: union and co_reported also validate at least
    # one upstream, but they are "two_or_more". nil when no validation says.
    def upstreams_facet
      meths = @validations.map(&:first)
      required = @validations.select { |meth, *| meth == :validate_required_options }.flat_map { |_meth, *names| names }
      if (%i[left right] - required).empty?
        "left_right"
      elsif meths.include?(:validate_at_least_two_upstreams)
        "two_or_more"
      elsif meths.include?(:validate_at_least_one_upstream)
        "one_or_more"
      elsif meths.include?(:validate_at_most_one_upstream)
        "none_or_one"
      elsif meths.include?(:validate_one_upstream)
        "one"
      elsif meths.include?(:validate_no_upstreams)
        "none"
      end
    end

    # The returns text that the metadata serves
    def get_returns
      returns
    end

    # The examples that the metadata of the operator with this name serves
    def examples_for(_name)
      examples
    end

    def arity
      case diagram_base
      when :set
        -1
      when :temporal, :cast
        1
      when :selection, nil
        0
      when :filter
        2
      else
        raise "#{name} has unknown diagram_base: #{diagram_base.pretty_inspect}"
      end
    end

    # The desc that the operator set (no_desc sets ""), else the standard
    # vocabulary text. A subclass does not inherit its parent's desc.
    def get_desc
      @desc || standard_description
    end

    def process_options(options)
      return {} if options.nil? || options.empty?

      # Build new hashes: the option hashes can be shared with a parent class
      options.transform_values do |v|
        v[:options].respond_to?(:call) ? v.merge(options: v[:options].call) : v
      end
    end

    def warn_about_missing_metadata
      missing = []
      missing << :categories if (@categories || []).empty?
      missing << :desc if get_desc.empty?
      missing << :diagram_base unless @diagram_base
      puts "#{just_class_name} is missing #{missing.join(', ')}" unless missing.empty?
    end

    # Each validation is [meth, *args]. Every argument reaches the hook, so
    # validate_required_options :left, :right marks both options.
    def derive_metadata_from_validations
      @validations.each do |meth, *args|
        hook = "#{meth}_to_metadata"
        send(hook, *args) if respond_to?(hook)
      end
    end

    def validate_no_upstreams_to_metadata(*_args)
      @min_upstreams = 0
      @max_upstreams = 0
    end

    def validate_one_upstream_to_metadata(*_args)
      @min_upstreams = 1
      @max_upstreams = 1
    end

    def validate_at_least_one_upstream_to_metadata(*_args)
      @min_upstreams = 1
      @max_upstreams = 99
    end

    def validate_at_most_one_upstream_to_metadata(*_args)
      @min_upstreams = 0
      @max_upstreams = 1
    end

    def validate_no_arguments_to_metadata(*_args)
      @arguments = []
    end

    # A subclass shares the option hashes that it inherits (see #inherited),
    # so mark a copy. Writing into the shared hash would mark the option as
    # required for the parent class too.
    def validate_required_options_to_metadata(*names)
      names.each do |name|
        @options[name] = @options.fetch(name).merge(required: true)
      end
    end

    def standard_description
      "Selects records based on the #{pref_name} vocabulary."
    end

    def no_desc
      desc ""
    end
  end
end
