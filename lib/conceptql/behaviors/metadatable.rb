# frozen_string_literal: true

module ConceptQL
  module Metadatable
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

    def basic_type(value = nil)
      return @basic_type unless value

      @basic_type = value
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

      upstream.basic_type @basic_type

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
        basic_type: @basic_type,
        deprecated: (true if deprecated), # nil for an operator that is not deprecated
        arity: arity,
        aliases: @aliases,
        spec_id: spec_id,
        returns: get_returns,
        examples: examples_for(name)
      }
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
      case basic_type
      when :set
        -1
      when :temporal, :cast
        1
      when :selection, nil
        0
      when :filter
        2
      else
        raise "#{name} has unknown basic_type: #{basic_type.pretty_inspect}"
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
      missing << :basic_type unless @basic_type
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
