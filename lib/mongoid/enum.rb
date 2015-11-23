require "mongoid/enum/enum_type"
require "mongoid/enum/invalid_key"
require "mongoid/enum/invalid_value"

module Mongoid # :nodoc:
  # Declare an enum field with scope and value checking helper methods. Example:
  #
  #   class Conversation
  #     include Mongoid::Document
  #     include Mongoid::Enum
  #
  #     enum status: [ :active, :archived ]
  #   end
  #
  #   # conversation.update! status: "active"
  #   conversation.active!
  #   conversation.active? # => true
  #   conversation.status  # => "active"
  #
  #   # conversation.update! status: "archived"
  #   conversation.archived!
  #   conversation.archived? # => true
  #   conversation.status    # => "archived"
  #
  #   conversation.status = nil
  #   conversation.status.nil? # => true
  #   conversation.status      # => nil
  #
  #
  # By default the whole label name is saved in the database as string, but you can
  # explicitly declare values for each label. Strings, numbers, booleans, nil and some
  # others types are allowed.
  #
  #   class Conversation
  #     include Mongoid::Document
  #     include Mongoid::Enum
  #
  #     enum status: { active: 0, archived: 1 }, _default: :active
  #   end
  #
  # The mappings are exposed through a class constant with the pluralized field name.
  # It defines the mapping using +HashWithIndifferentAccess+:
  #
  #   Conversation::STATUSES[:active]    # => 0
  #   Conversation::STATUSES["archived"] # => 1
  #
  #
  # Scopes based on the allowed values of the enum field will be provided
  # as well. With the above example:
  #
  #   Conversation.active
  #   Conversation.archived
  #
  # Of course, you can also query them directly if the scopes don't fit your
  # needs:
  #
  #   Conversation.where(status: [:active, :archived])
  #   Conversation.not.where(status: :active)
  #
  #
  # Defining an enum automatically adds a validator on its field. Assigning values
  # not included in enum definition will make the document invalid.
  #
  #   conversation = Conversation.new
  #   conversation.status = :unknown
  #   conversation.valid? # false
  #
  # Default validator allows nil values. Add your own presence validator if you require
  # a value for the enum field.
  #
  #   class Conversation
  #     include Mongoid::Document
  #     include Mongoid::Enum
  #
  #     enum status: { active: 0, archived: 1 }, _default: :active
  #
  #     validates :status, presence: true
  #   end
  #
  #
  # You can use the +:_prefix+ or +:_suffix+ options when you need to define
  # multiple enums with same values. If the passed value is +true+, the methods
  # are prefixed/suffixed with the name of the field. It is also possible to
  # supply a custom value:
  #
  #   class Conversation
  #     include Mongoid::Document
  #     include Mongoid::Enum
  #
  #     enum status: [:active, :archived], _suffix: true
  #     enum comments_status: [:active, :inactive], _prefix: :comments
  #   end
  #
  # With the above example, the bang and predicate methods along with the
  # associated scopes are now prefixed and/or suffixed accordingly:
  #
  #   conversation.active_status!
  #   conversation.archived_status? # => false
  #
  #   conversation.comments_inactive!
  #   conversation.comments_active? # => false
  #
  #
  # If you want to you can give nil value an explicit label.
  #
  #   class Part
  #     include Mongoid::Document
  #     include Mongoid::Enum
  #
  #     enum quality_control: {pending: nil, passed: true, failed: false}, _prefix: :qc
  #   end
  #
  #   part = Part.qc_pending.first
  #   part.qc_pending?        # true
  #   part["quality_control"] # nil
  #   part.quality_control    # "pending"
  #   part.qc_passed!
  #   part.quality_control    # "passed"
  #   part["quality_control"] # true
  module Enum
    extend ActiveSupport::Concern

    included do
      class_attribute(:enums)
      self.enums = {}
    end

    # :nodoc:
    module ClassMethods
      # Define enum field on the model. See description of Mongoid::Enum
      def enum(definitions)
        klass = self
        enum_prefix = definitions.delete(:_prefix)
        enum_suffix = definitions.delete(:_suffix)
        default_key = definitions.delete(:_default)

        definitions.each do |name, values|
          enum_values = ActiveSupport::HashWithIndifferentAccess.new
          name        = name.to_sym
          const_name  = name.to_s.pluralize.upcase

          if klass.const_defined?(const_name)
            fail ArgumentError, "Defining enum :#{name} on #{klass} would " \
              "overwrite existing constant #{klass}::#{const_name}"
          end

          detect_enum_conflict!(name, name)
          detect_enum_conflict!(name, "#{name}=")

          if values.respond_to? :each_pair
            values.each_pair { |key, value| enum_values[key.to_s] = value }
          else
            values.each { |v| enum_values[v.to_s] = v.to_s }
          end

          enum_values.each do |key, value|
            key.freeze
            value.freeze
          end
          enum_values.freeze

          if default_key && !enum_values.key?(default_key)
            fail ArgumentError, "default key #{default_key} is not among enum options"
          end

          field name, type: EnumType.new(enum_values), default: default_key

          klass.const_set const_name, enum_values
          klass.validates name,
                          inclusion: {
                            in: enum_values.keys,
                            allow_nil: true,
                            message: "is invalid"
                          }

          _enum_methods_module.module_eval do
            enum_values.each do |key, value|
              if enum_prefix == true
                prefix = "#{name}_"
              elsif enum_prefix
                prefix = "#{enum_prefix}_"
              end
              if enum_suffix == true
                suffix = "_#{name}"
              elsif enum_suffix
                suffix = "_#{enum_suffix}"
              end

              value_method_name = "#{prefix}#{key}#{suffix}"

              # def active?() status == 0 end
              klass.send(:detect_enum_conflict!, name, "#{value_method_name}?")
              define_method("#{value_method_name}?") { self[name] == value }

              # def active!() update! status: :active end
              klass.send(:detect_enum_conflict!, name, "#{value_method_name}!")
              define_method("#{value_method_name}!") { update! name => key }

              # scope :active, -> { where status: 0 }
              klass.send(:detect_enum_conflict!, name, value_method_name, true)
              klass.scope value_method_name, -> { klass.where name => key }
            end
          end

          # dup so children classes don't add their own enums to parent definitions
          self.enums = enums.dup

          enums[name] = enum_values
          enums.freeze
        end
      end

      private

      def _enum_methods_module
        @_enum_methods_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      # :nodoc:
      ENUM_CONFLICT_MESSAGE = \
        "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
        "this will generate %{type} method \"%{method}\", which is already defined."

      def detect_enum_conflict!(enum_name, method_name, class_method = false)
        method_name = method_name.to_sym

        if class_method
          if self.respond_to?(method_name, true)
            raise_conflict_error(enum_name, method_name, "class")
          end
        else
          if Mongoid.destructive_fields.include?(method_name) ||
             instance_methods.include?(method_name)
            raise_conflict_error(enum_name, method_name, "instance")
          end
        end
      end

      def raise_conflict_error(enum_name, method_name, type)
        fail ArgumentError, ENUM_CONFLICT_MESSAGE % {
          enum: enum_name,
          klass: name,
          type: type,
          method: method_name
        }
      end
    end
  end
end
