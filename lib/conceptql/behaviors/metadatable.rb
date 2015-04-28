require 'facets/kernel/meta_def'
require 'facets/string/snakecase'

module Metadatable
  def preferred_name(value = nil)
    return @preferred_name unless value
    @preferred_name = value
  end

  def desc(value = nil)
    return @desc unless value
    @desc = value
  end

  def predominant_types(*values)
    return @predominant_types if values.empty?
    @predominant_types = values
  end

  def argument(name, options = {})
    (@arguments ||= [])
    @arguments << [name, options]
  end

  def option(name, options = {})
    @options ||= {}
    @options[name] = options
  end

  def types(*type_list)
    @types = type_list
    define_method(:types) do
      type_list
    end
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

    case @max_upstreams
    when 1
      upstream.allows_one_upstream
    when 99
      upstream.allows_many_upstreams
    end
  end

  def to_metadata
    {
      preferred_name: @preferred_name || humanized_class_name,
      operation: just_class_name.snakecase,
      max_upstreams: @max_upstreams || 0,
      arguments: @arguments || [],
      options: @options || {},
      predominant_types: @types || @predominant_types || [],
      desc: @desc,
      categories: @categories || []
    }
  end
end

