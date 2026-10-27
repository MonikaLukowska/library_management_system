require "rails_helper"

RSpec.describe ChangeBookStatus do
  include ActiveSupport::Testing::TimeHelpers

  def create_book
    Book.create!(serial_number: "000123", title: "Dune", author: "Frank Herbert")
  end

  def create_reader(**overrides)
    Reader.create!({ card_number: "000123", full_name: "Ada Lovelace", email: "ada@example.com" }.merge(overrides))
  end

  it "sets the due date 30 days after the borrow date" do
    book = create_book
    reader = create_reader

    travel_to Date.new(2026, 10, 27) do
      expect(ChangeBookStatus.call(book, status: "borrowed", card_number: reader.card_number)).to be(true)
    end

    loan = book.open_borrowing
    expect(loan.borrowed_on).to eq(Date.new(2026, 10, 27))
    expect(loan.due_on).to eq(Date.new(2026, 11, 26))
    expect(loan.returned_on).to be_nil
    expect(book.status).to eq("borrowed")
  end

  it "schedules a reminder three days before the due date and on the due date" do
    book = create_book
    reader = create_reader

    travel_to Time.zone.local(2026, 10, 27, 9) do
      ChangeBookStatus.call(book, status: "borrowed", card_number: reader.card_number)
      loan = book.open_borrowing

      expect(ReturnReminderJob).to have_been_enqueued.with(loan.id, loan.due_on, ReturnReminderJob::UPCOMING).at(Time.zone.local(2026, 11, 23))
      expect(ReturnReminderJob).to have_been_enqueued.with(loan.id, loan.due_on, ReturnReminderJob::DUE).at(Time.zone.local(2026, 11, 26))
    end
  end

  it "rejects a second open loan for the same book" do
    book = create_book
    ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)
    other = create_reader(card_number: "000124", email: "grace@example.com", full_name: "Grace Hopper")

    expect(ChangeBookStatus.call(book, status: "borrowed", card_number: other.card_number)).to be(false)
    expect(book.errors[:base]).to eq([ "Book is already borrowed" ])
    expect(book.borrowings.count).to eq(1)
  end

  it "allows another loan after the book is returned" do
    book = create_book
    ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)
    expect(ChangeBookStatus.call(book, status: "available", card_number: nil)).to be(true)
    expect(book.status).to eq("available")

    other = create_reader(card_number: "000124", email: "grace@example.com", full_name: "Grace Hopper")

    expect(ChangeBookStatus.call(book, status: "borrowed", card_number: other.card_number)).to be(true)
    expect(book.borrowings.count).to eq(2)
    expect(book.open_borrowing.reader).to eq(other)
  end
end
