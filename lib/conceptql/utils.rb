require 'json'

module ConceptQL
  module Utils
    class << self
      def rekey(h)
        # Cheap and easy way to mimic Rails' Hash#symbolize_keys
        # Thanks to: https://stackoverflow.com/a/26041090
        JSON.parse(h.to_json, symbolize_names: true)
      end

      def blank?(thing)
        thing.nil? || thing.empty?
      end

      def present?(thing)
        !blank?(thing)
      end

      # Cut and paste from Facets
      def snakecase(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr('-', '_').
          gsub(/\s/, '_').
          gsub(/__+/, '_').
          downcase
      end
    end
  end
end
