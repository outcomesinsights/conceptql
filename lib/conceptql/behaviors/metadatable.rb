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

  def allows_many_children
    @max_children = 99
  end

  def allows_one_child
    @max_children = 1
  end

  def just_class_name
    self.to_s.split('::').last
  end

  def inherited(child)
    (@options || {}).each do |name, opt|
      child.option name, opt
    end
  end

  def to_metadata
    {
      preferred_name: @preferred_name || just_class_name,
      operation: just_class_name.snakecase,
      max_children: @max_children || 0,
      arguments: @arguments || [],
      options: @options || {},
      predominant_types: @types || @predominant_types || [],
      desc: @desc
    }
  end
end

