# frozen_string_literal: true

require 'logger'
module ConceptQL
  def self.logger
    @logger ||= begin
      l = Logger.new('/tmp/cql.log')
      l.level = Logger::DEBUG
      l
    end
  end
end
