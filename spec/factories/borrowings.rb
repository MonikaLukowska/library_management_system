FactoryBot.define do
  factory :borrowing do
    book
    reader
    borrowed_on { Date.current - 12 }
    due_on { borrowed_on + Borrowing::LOAN_PERIOD_IN_DAYS }

    trait :returned do
      borrowed_on { Date.current - 80 }
      returned_on { Date.current - 60 }
      due_on { Date.current - 50 }
    end
  end
end
