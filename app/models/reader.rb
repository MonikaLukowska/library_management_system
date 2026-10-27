class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error

  before_validation :normalize_email

  validates :card_number, presence: true, uniqueness: true, format: { with: /\A\d{6}\z/ }
  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

    def normalize_email
      self.email = email.strip.downcase if email.present?
    end
end
