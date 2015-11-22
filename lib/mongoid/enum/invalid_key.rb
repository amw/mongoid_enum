module Mongoid
  module Enum
    # raised when InvalidKey is forced to be saved in DB (skipping validation)
    class InvalidKeyError < StandardError
    end

    # Internal: Wraps invalid keys passed to setter so that getter returns the same key.
    class InvalidKey # :nodoc:
      attr_reader :original_key

      def initialize(key)
        @original_key = key
      end

      def raise_error
        raise InvalidKeyError, "invalid enum key: #{original_key}"
      end
      alias_method :bson_type, :raise_error
      alias_method :to_bson, :raise_error
    end
  end
end
