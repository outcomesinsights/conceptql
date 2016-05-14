require 'facets/kernel/meta_def'
require 'facets/string/snakecase'
require 'facets/string/titlecase'

module Metadatable
  def preferred_name(value = nil)
    return @preferred_name unless value
    @preferred_name = value
  end

  def desc(value = nil)
    return @desc unless value
    @desc = value
  end

  def predominant_domains(*values)
    return @predominant_domains if values.empty?
    @predominant_domains = values
  end

  def argument(name, options = {})
    (@arguments ||= [])
    @arguments << [name, auto_label(name, options)]
  end

  def option(name, options = {})
    @options ||= {}
    @options[name] = auto_label(name, options)
  end

  def auto_label(name, opts = {})
    return opts if opts[:label]
    return opts.merge(label: name.to_s.split('_').join(' ').titlecase) unless opts[:type] == :codelist
    opts.merge(label: pref_name + " Codes")
  end

  def domains(*domain_list)
    @domains = domain_list
    define_method(:domains) do
      domain_list
    end
    if domain_list.length == 1
      define_method(:domain) do
        domain_list.first
      end
    end
  end

  def basic_type(value = nil)
    return @basic_type unless value
    @basic_type = value
  end

  def allows_many_upstreams
    @max_upstreams = 99
  end

  def allows_one_upstream
    @max_upstreams = 1
  end

  def just_class_name
    self.to_s.split('::').last
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

  def to_metadata(name, opts = {})
    derive_metadata_from_validations
    warn_about_missing_metadata if opts[:warn]
    {
      name: name,
      preferred_name: pref_name,
      operation: just_class_name.snakecase,
      min_upstreams: @max_upstreams || 0,
      max_upstreams: @max_upstreams || 0,
      arguments: @arguments || [],
      options: @options || {},
      predominant_domains: @domains || @predominant_domains || [],
      desc: get_desc,
      categories: @categories || [],
      basic_type: @basic_type
    }
  end

  def get_desc
    @desc ||= standard_description
  end

  def warn_about_missing_metadata
    missing = []
    missing << :categories if (@categories || []).empty?
    missing << :desc if get_desc.empty?
    missing << :basic_type unless @basic_type
    puts "#{just_class_name} is missing #{missing.join(", ")}" unless missing.empty?
  end

  def derive_metadata_from_validations
    instance_variable_get(:@validations).each do |meth, args|
      meth = meth.to_s + "_to_metadata"
      send(meth, args) if respond_to?(meth)
    end
  end

  def validate_no_upstreams_to_metadata(*args)
    @min_upstreams = 0
    @max_upstreams = 0
  end

  def validate_one_upstream_to_metadata(*args)
    @min_upstreams = 1
    @max_upstreams = 1
  end

  def validate_at_least_one_upstream_to_metadata(*args)
    @min_upstreams = 1
    @max_upstreams = 99
  end

  def validate_at_most_one_upstream_to_metadata(*args)
    @min_upstreams = 0
    @max_upstreams = 1
  end

  def validate_no_arguments_to_metadata(*args)
    @arguments = []
  end

  def validate_required_options_to_metadata(*args)
    args.each do |opt_name|
      @options[opt_name][:required] = true
    end
  end

  def standard_description
    table = (!@domains.nil? && @domains.first)
    table ||= (!predominant_domains.nil? && predominant_domains.first)
    raise "Can't create description for #{pref_name}" unless table

    "Selects results from the #{table} table where #{table}'s source value matches the given #{pref_name} codes."
  end

  def no_desc
    desc ''
  end
end
