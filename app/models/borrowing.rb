class Borrowing < ApplicationRecord
  belongs_to :book
  belongs_to :reader

  validates :borrowed_on, :due_on, presence: true

  LOAN_PERIOD_IN_DAYS = 30
end
