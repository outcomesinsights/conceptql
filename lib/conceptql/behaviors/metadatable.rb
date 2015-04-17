require 'facets/kernel/meta_def'
require 'facets/string/methodize'

module Metadatable
  def name(value = nil)
    return @name unless value
    @name = value
  end

  def desc(value = nil)
    return @desc unless value
    @desc = value
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
    define_method(:types) do
      type_list
    end
  end

  def many_kids
    @max_kids = 99
  end

  def one_kid
    @max_kids = 1
  end

  def to_metadata
    {
      name: @name || self.to_s,
      operation: self.to_s.methodize,
      max_kids: @max_kids || 0,
      arguments: @arguments || [],
      options: @options || {},
      desc: @desc
    }
  end
end

