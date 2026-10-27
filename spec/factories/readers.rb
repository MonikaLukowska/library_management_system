FactoryBot.define do
  factory :reader do
    sequence(:card_number) { |number| format("%06d", number) }
    sequence(:full_name) { |number| "Reader #{number}" }
    sequence(:email) { |number| "reader#{number}@example.com" }
  end
end
