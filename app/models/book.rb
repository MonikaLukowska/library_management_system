class Book < ApplicationRecord
  validates :serial_number, presence: true, uniqueness: true, format: { with: /\A\d{6}\z/ }
  validates :title, :author, presence: true
end
