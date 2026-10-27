class Book < ApplicationRecord
  has_many :borrowings, -> { order(:borrowed_on, :id) }, dependent: :restrict_with_error
  has_one :open_borrowing, -> { where(returned_on: nil) }, class_name: "Borrowing", inverse_of: :book

  validates :serial_number, presence: true, uniqueness: true, format: { with: /\A\d{6}\z/ }
  validates :title, :author, presence: true

  def status
    current_borrowing ? "borrowed" : "available"
  end

  def current_borrowing
    if borrowings.loaded?
      borrowings.find { |borrowing| borrowing.returned_on.nil? }
    else
      open_borrowing
    end
  end
end
