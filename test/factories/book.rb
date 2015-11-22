class Book
  include Mongoid::Document
  include Mongoid::Enum

  field :author_id, type: BSON::ObjectId
  field :format, type: String
  field :name, type: String

  enum status: [:proposed, :written, :published]
  # {"read": 3} conflicts with Mongoid read options so it's "finished" instead
  enum read_status: { unread: 0, reading: 2, finished: 3 }
  enum nullable_status: [:single, :married]
  enum language: [:english, :spanish, :french], _prefix: :in
  enum author_visibility: [:visible, :invisible], _prefix: true
  enum illustrator_visibility: [:visible, :invisible], _prefix: true
  enum font_size: { small: 8, medium: 10, large: 12 }, _prefix: :with,
       _suffix: true, _default: :medium
  enum quality_control: { pending: nil, passed: true, failed: false }, _prefix: :qc

  def published!
    super
    "do publish work..."
  end
end

FactoryGirl.define do
  factory :book do
    format "paperback"
    status :published
    read_status :finished
    language :english
    author_visibility :visible
    illustrator_visibility :visible
    font_size :medium
  end

  factory :default_book, class: Book do
  end
end
