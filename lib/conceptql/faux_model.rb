require "active_support/core_ext/string/inflections"
require "ostruct"

module ConceptQL
  module Models
    class FauxpenStruct < OpenStruct
      def initialize(hash = nil)
        @table = {}
        if hash
          hash.each_pair do |k, v|
            self.send("#{k}=", v)
          end
        end
      end
      undef :table
    end

    class FauxModel < FauxpenStruct
      class << self
        def has_many(association, opts = {})
          define_method("#{association}=") do |v|
            klass = klassify(association, opts)
            self[association] = v.map { |json| klass.new(json) }
          end
        end

        def has_one(association, opts = {})
          define_method("#{association}=") do |v|
            klass = klassify(association, opts)
            self[association] = klass.new(v)
          end
        end

        def json_fields(*fields)
          fields.each do |field|
            define_method("#{field}=") do |v|
              self[field] = v.nil? ? nil : JSON.parse(v)
            end
          end
        end

        def date_fields(*fields)
          fields.each do |field|
            define_method("#{field}=") do |v|
              self[field] = v.nil? ? nil : Date.parse(v)
            end
          end
        end
      end

      def klassify(association, opts = {})
        klass_name = (opts[:class_name] || association.to_s.singularize.camelcase)
        ("ConceptQL::Models::" + klass_name).constantize
      end
    end
  end
end
