require "test_helper"

class EnumTest < ActiveSupport::TestCase
  def new_book_class(&block)
    klass = Class.new do
      include Mongoid::Document
      include Mongoid::Enum

      def self.name
        "Book"
      end

      store_in collection: "books"
    end

    klass.class_eval(&block) if block_given?

    klass
  end

  setup do
    @book = create(:book)
  end

  test "query state by predicate" do
    assert @book.published?
    assert_not @book.written?
    assert_not @book.proposed?

    assert @book.finished?
    assert @book.in_english?
    assert @book.author_visibility_visible?
    assert @book.illustrator_visibility_visible?
    assert @book.with_medium_font_size?
  end

  test "query state with strings" do
    assert_equal "published", @book.status
    assert_equal "finished", @book.read_status
    assert_equal "english", @book.language
    assert_equal "visible", @book.author_visibility
    assert_equal "visible", @book.illustrator_visibility
  end

  test "find via scope" do
    assert_equal @book, Book.published.desc(:_id).first
    assert_equal @book, Book.finished.desc(:_id).first
    assert_equal @book, Book.in_english.desc(:_id).first
    assert_equal @book, Book.author_visibility_visible.desc(:_id).first
    assert_equal @book, Book.illustrator_visibility_visible.desc(:_id).first
  end

  test "find via where with labels" do
    assert_equal @book, Book.where(status: :published).desc(:_id).first
    assert_not_equal @book, Book.where(status: :written).desc(:_id).first
    assert_equal @book, Book.where(:read_status.in => [:finished]).desc(:_id).first
    assert_not_equal @book, Book.where(:read_status.in => [:reading]).desc(:_id).first
  end

  test "find via where with values" do
    published = Book::STATUSES[:published]
    written = Book::STATUSES[:written]
    reading = Book::READ_STATUSES["reading"]
    finished = Book::READ_STATUSES["finished"]

    assert_equal @book, Book.where(status: published).desc(:_id).first
    assert_not_equal @book, Book.where(status: written).desc(:_id).first
    assert_equal @book, Book.where(:read_status.in => [finished]).desc(:_id).first
    assert_not_equal @book, Book.where(:read_status.in => [reading]).desc(:_id).first
  end

  test "build from scope" do
    assert Book.written.build.written?
    assert_not Book.written.build.proposed?
  end

  test "update by declaration" do
    assert @book.published?
    @book.written!
    assert @book.written?
    assert_not @book.published?
    @book.in_english!
    assert @book.in_english?
    @book.author_visibility_visible!
    assert @book.author_visibility_visible?
  end

  test "update by setter" do
    @book.update! status: :written, read_status: :reading
    assert @book.written?
    assert_not @book.published?
    assert @book.reading?
    assert_not @book.finished?
  end

  test "nil is allowed value" do
    assert @book.qc_pending?
    assert_nil @book["quality_control"]
    assert_equal @book.id, Book.qc_pending.desc(:_id).first.id
    @book.qc_passed!
    assert_not_equal @book.id, Book.qc_pending.desc(:_id).first.id
  end

  test "atomic set on instance" do
    assert_equal "finished", @book.read_status
    @book.set read_status: :reading
    assert_equal "reading", @book.read_status
    assert_equal 2, @book["read_status"]
    @book.reload
    assert_equal "reading", @book.read_status
    assert_equal 2, @book["read_status"]
  end

  test "atomic set on scope" do
    assert_equal "finished", @book.read_status
    Book.where(_id: @book.id).set read_status: Book::READ_STATUSES[:reading]
    @book.reload
    assert_equal "reading", @book.read_status
    assert_equal 2, @book["read_status"]
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert @book.published?
  end

  test "direct symbol assignment" do
    @book.status = :written
    assert @book.written?
  end

  test "direct string assignment" do
    @book.status = "written"
    assert @book.written?
  end

  test "remembers invalid assignment" do
    @book.status = "invalid-status-key"
    assert_not @book.written?
    assert_equal "invalid-status-key", @book.status
  end

  test "reports invalid assignment" do
    @book.status = "invalid-status-key"
    assert_not @book.written?
    assert_not @book.valid?
    assert_equal ["Status is invalid"], @book.errors.full_messages
  end

  test "raises on save skipping validation" do
    @book.status = "invalid-status-key"
    assert_not @book.written?
    assert_not @book.valid?
    e = assert_raises Mongoid::Enum::InvalidKeyError do
      @book.save validate: false
    end
    assert_equal "invalid enum key: invalid-status-key", e.message
  end

  test "reports invalid value read from db" do
    Book.where(_id: @book.id).set read_status: 10
    @book.reload
    assert_not @book.finished?
    assert_not @book.valid?
    assert_equal ["Read status is invalid"], @book.errors.full_messages
    assert_equal 10, @book["read_status"]
    assert @book.read_status.is_a? Mongoid::Enum::InvalidValue
    assert_equal 10, @book.read_status.database_value
  end

  test "enum changed attributes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal Book::STATUSES[old_status], @book.changed_attributes["status"]
    assert_equal Book::LANGUAGES[old_language], @book.changed_attributes["language"]
  end

  test "enum changes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal [old_status, "proposed"], @book.changes["status"]
    assert_equal [old_language, "spanish"], @book.changes["language"]
    assert_equal [old_status, "proposed"], @book.status_change
    assert_equal [old_language, "spanish"], @book.language_change
  end

  test "enum attribute changed" do
    @book.status = :proposed
    @book.language = :french
    assert @book.status_changed?
    assert @book.language_changed?
  end

  test "enum didn't change" do
    old_status = @book.status
    @book.status = old_status
    assert_not @book.status_changed?
  end

  test "persist changes that are dirty" do
    @book.status = :proposed
    assert @book.status_changed?
    @book.status = :written
    assert @book.status_changed?
  end

  test "reverted changes that are not dirty" do
    old_status = @book.status
    @book.status = :proposed
    assert @book.status_changed?
    @book.status = old_status
    assert_not @book.status_changed?
  end

  test "reverted changes are not dirty going from nil to value and back" do
    book = Book.create!(nullable_status: nil)

    book.nullable_status = :married
    assert book.nullable_status_changed?

    book.nullable_status = nil
    assert_not book.nullable_status_changed?
  end

  test "NULL values from database should be casted to nil" do
    Book.where(id: @book.id).update_all(status: nil)
    assert_nil @book.reload.status
  end

  test "assign nil value" do
    @book.status = nil
    assert_nil @book.status
  end

  test "assign empty string value" do
    @book.status = ""
    assert_nil @book.status
  end

  test "assign long empty string value" do
    @book.status = "   "
    assert_nil @book.status
  end

  test "constant to access the mapping" do
    assert_equal 0, Book::READ_STATUSES[:unread]
    assert_equal 2, Book::READ_STATUSES["reading"]
    assert_equal 3, Book::READ_STATUSES[:finished]
  end

  test "building new objects with enum scopes" do
    assert Book.written.build.written?
    assert Book.finished.build.finished?
    assert Book.reading.build.reading?
    assert Book.in_spanish.build.in_spanish?
    assert Book.illustrator_visibility_invisible.build.illustrator_visibility_invisible?
  end

  test "creating new objects with enum scopes" do
    assert Book.written.create.written?
    assert Book.finished.create.finished?
    assert Book.reading.create.reading?
    assert Book.in_spanish.create.in_spanish?
    assert Book.illustrator_visibility_invisible.create.illustrator_visibility_invisible?
  end

  test "_before_type_cast returns the enum label (required for form fields)" do
    assert_equal :published, @book.status_before_type_cast
    assert_equal :finished, @book.read_status_before_type_cast
    @book.status = 123
    assert_equal 123, @book.status_before_type_cast
  end

  test "reserved enum names" do
    klass = new_book_class do
      enum status: [:proposed, :written, :published]
      field :conflicting_field
    end

    conflicts = [:save, :attributes, :conflicting_field]

    conflicts.each_with_index do |name, i|
      e = assert_raises(ArgumentError) do
        klass.class_eval { enum name => ["value_#{i}"] }
      end
      assert_match(
        /You tried to define an enum named \"#{name}\" on the model/,
        e.message
      )
    end
  end

  test "reserved enum values" do
    klass = new_book_class do
      enum status: [:proposed, :written, :published]
    end

    conflicts = [
      :new,      # generates a scope that conflicts with an AR class method
      :valid,    # generates #valid?, which conflicts with an AR method
      :save,     # generates #save!, which conflicts with an AR method
      :proposed, # same value as an existing enum
      :public, :private, :protected, # some important methods on Module and Class
      :name, :parent, :superclass
    ]

    conflicts.each_with_index do |value, i|
      e = assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        klass.class_eval { enum "status_#{i}" => [value] }
      end
      assert_match(/You tried to define an enum named .* on the model/, e.message)
    end
  end

  test "validate uniqueness" do
    klass = new_book_class do
      enum read_status: { unread: 0, reading: 2, finished: 3 }
      validates_uniqueness_of :read_status
    end

    klass.delete_all
    klass.create!(read_status: "reading")
    book = klass.new(read_status: "unread")
    assert book.valid?
    book.read_status = "reading"
    assert_not book.valid?
  end

  test "enums are distinct per class" do
    klass1 = new_book_class do
      enum status: [:proposed, :written]
    end

    klass2 = new_book_class do
      enum status: [:drafted, :uploaded]
    end

    book1 = klass1.proposed.create!
    book1.status = :written
    assert_equal %w(proposed written), book1.status_change

    book2 = klass2.drafted.create!
    book2.status = :uploaded
    assert_equal %w(drafted uploaded), book2.status_change
  end

  test "enums are inheritable" do
    subklass1 = Class.new(Book)

    subklass2 = Class.new(Book) do
      enum status2: [:drafted, :uploaded]
    end

    book1 = subklass1.proposed.create!
    book1.status = :written
    assert_equal %w(proposed written), book1.status_change

    book2 = subklass2.drafted.create!
    book2.status2 = :uploaded
    assert_equal %w(drafted uploaded), book2.status2_change
  end

  test "declare multiple enums at a time" do
    klass = new_book_class do
      enum status: [:proposed, :written, :published],
           nullable_status: [:single, :married]
    end

    book1 = klass.proposed.create!
    assert book1.proposed?

    book2 = klass.single.create!
    assert book2.single?
  end

  test "query state by predicate with prefix" do
    assert @book.author_visibility_visible?
    assert_not @book.author_visibility_invisible?
    assert @book.illustrator_visibility_visible?
    assert_not @book.illustrator_visibility_invisible?
  end

  test "query state by predicate with custom prefix" do
    assert @book.in_english?
    assert_not @book.in_spanish?
    assert_not @book.in_french?
  end

  test "uses default status when no status is provided in fixtures" do
    book = build(:default_book)
    assert_nil book.status
    assert book.with_medium_font_size?
    assert_equal 10, book["font_size"]
    assert_equal "medium", book.font_size
  end

  test "exposes defined enums" do
    assert Book.enums
    assert Book.enums[:read_status]
    assert_equal 2, Book.enums[:read_status]["reading"]
    assert_equal 2, Book.enums[:read_status][:reading]
  end
end
