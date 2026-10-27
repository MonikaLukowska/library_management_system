require "rails_helper"

RSpec.describe Borrowing, type: :model do
  it "enforces one open loan per book in the database" do
    book = create(:book)
    create(:borrowing, book:)

    expect {
      build(:borrowing, book:, borrowed_on: Date.current, due_on: Date.current + 30).save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
