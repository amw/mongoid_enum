# Introduction

Enum implementation for Mongoid. Similar to that found in ActiveRecord.

# Installation

    gem "mongoid_enum"

# Usage

By default values saved to DB are strings matching enum labels.

    class Conversation
      include Mongoid::Document
      include Mongoid::Enum

      enum status: [ :active, :archived ]
    end

    conversation = Conversation.active.first
    conversation.active?   # true
    conversation.archived! # immediately saves document
    conversation.active?   # false
    conversation["status"] # "archived"

You can use other Mongo value types (numbers, booleans, nil) when explicitly defining
the enum mapping:

    class Part
      include Mongoid::Document
      include Mongoid::Enum

      enum quality_control: {pending: nil, passed: true, failed: false}, _prefix: :qc
    end

    part = Part.qc_pending.first
    part.quality_control    # "pending"
    part.qc_passed!
    part.quality_control    # "passed"
    part["quality_control"] # true

Enum values are validated.

    part.quality_control = "unknown value"
    part.valid? # false

You can access the mapping as hash with indifferent access via class level constant.
Constant name is a pluralized field name set in SCREAMING\_SNAKE\_CASE.

    Part::QUALITY_CONTROLS["passed"] # true
    Part::QUALITY_CONTROLS[:failed]  # false

# Differences from ActiveRecord

1. Default values are strings, not integers. I think it fits MongoDB better.

2. Mapping hash is accessible via class constant instead of class method. I prefer
   constant because it is accessible without prefix both on class methods and instance
   methods. Also I think SCREAMING\_SNAKE\_CASE is less likely to cause name conflicts.

3. I do not raise exception when invalid value is assigned. Instead document fails
   validation. Assigned invalid value is remembered and can be corrected in forms.

# Credits

Original implementation for ActiveRecord was created by David Heinemeier Hansson.
Following modifications by other Rails contributors. Port to Mongoid prepared by Adam
Wróbel.
