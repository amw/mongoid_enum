module Mongoid
  module Enum
    # Internal: Wraps invalid keys passed to setter so that getter returns the same key.
    class InvalidKey # :nodoc:
      attr_reader :original_key

      def initialize(key)
        @original_key = key
      end
    end
  end
end
