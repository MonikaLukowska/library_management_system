require "rails_helper"

RSpec.describe Borrowing, type: :model do
  it "enforces one open loan per book in the database" do
    book = Book.create!(serial_number: "000123", title: "Dune", author: "Frank Herbert")
    reader = Reader.create!(card_number: "000123", full_name: "Ada Lovelace", email: "ada@example.com")
    other = Reader.create!(card_number: "000124", full_name: "Grace Hopper", email: "grace@example.com")
    Borrowing.create!(book: book, reader: reader, borrowed_on: Date.current, due_on: Date.current + 30)

    expect {
      Borrowing.new(book: book, reader: other, borrowed_on: Date.current, due_on: Date.current + 30).save(validate: false)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
