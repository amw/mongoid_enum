module Mongoid
  module Enum
    # Public: Wraps invalid values loaded from DB before returning them via getter.
    class InvalidValue
      # Public: Holds the value loaded from DB that is not part of defined enum.
      attr_reader :database_value

      # :nodoc:
      def initialize(value)
        @database_value = value
      end
    end
  end
end
