require "forwardable"

module ConceptQL
  module Validators
    module Warners
      class CodesWarner
        attr_reader :operator

        extend Forwardable
        def_delegators :@operator, :arguments, :select_all?, :code_regexp, :vocabulary_id, :lexicon

        def initialize(op)
          @operator = op
        end

        def warnings
          return @warnings if defined?(@warnings)

          @warnings = {}

          bad_args = bad_arguments(arguments.dup)
          if unknown_vocabs.empty?
            unknown_codes(arguments.dup, bad_args)
          end
          @warnings
        end

        def bad_arguments(args)
          return [] unless code_regexp
          return [] if respond_to?(:select_all?) && select_all?
          bad_arguments = args.reject do |arg|
            code_regexp === arg
          end
          add_warning("improperly formatted code", *bad_arguments) unless bad_arguments.empty?
          bad_arguments
        end

        def unknown_vocabs
          vocabs = Array(vocabulary_id).zip(lexicon.translate_vocab_id(vocabulary_id))
          unknown_vocabs = vocabs.select { |k, v| v.nil? }.to_h
          add_warning("unknown vocabularies, no validation possible", *(unknown_vocabs.keys)) unless unknown_vocabs.empty?
          unknown_vocabs
        end


        def unknown_codes(args, badly_formatted_args)
          args -= badly_formatted_args
          missing_args = args - lexicon.known_codes(vocabulary_id, args)
          unless missing_args.empty?
            add_warning("unknown code(s)", *missing_args)
          end
          missing_args
        end

        def add_warning(key, *values)
          @warnings[key] = values
        end
      end
    end
  end
end
