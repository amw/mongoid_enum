module Mongoid
  module Enum
    # Internal: Mapping wrapper used as type for enum fields.
    #
    # Handles label-value conversion.
    class EnumType # :nodoc:
      attr_reader :mappings

      def initialize(mappings)
        @mappings = mappings
      end

      def mongoize(key)
        if key.blank?
          value = nil
        elsif mappings.key? key
          value = mappings[key]
        elsif mappings.value? key
          # XXX Mongoid may try to mongoize multiple times so if key is a valid value
          # assume that it has already been converted to value.
          value = key
        else
          value = Enum::InvalidKey.new(key)
        end
        value
      end
      alias_method :evolve, :mongoize

      def demongoize(value)
        if mappings.value? value
          key = mappings.key value
        elsif value.blank?
          key = nil
        elsif value.is_a? Enum::InvalidKey
          key = value.original_key
        else
          key = Enum::InvalidValue.new(value)
        end
        key
      end
    end
  end
end
