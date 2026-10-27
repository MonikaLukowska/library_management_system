FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |number| format("%06d", number) }
    sequence(:title) { |number| "Book #{number}" }
    sequence(:author) { |number| "Author #{number}" }
  end
end
