require "rails_helper"

RSpec.describe Book, type: :model do
  def build_book(**overrides)
    Book.new({
      serial_number: "000123",
      title: "Dune",
      author: "Frank Herbert"
    }.merge(overrides))
  end

  it "keeps a six-digit serial number" do
    book = build_book

    expect(book.save).to be(true)
    expect(book.serial_number).to eq("000123")
  end

  it "rejects a serial number that is not six digits" do
    book = build_book(serial_number: "12345")

    expect(book).not_to be_valid
    expect(book.errors[:serial_number]).to be_present
  end

  it "rejects a duplicate serial number" do
    build_book.save!

    duplicate = build_book(title: "Other", author: "Someone")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:serial_number]).to be_present
  end

  it "rejects a blank title" do
    book = build_book(title: "  ")

    expect(book).not_to be_valid
    expect(book.errors[:title]).to be_present
  end

  it "rejects a blank author" do
    book = build_book(author: "  ")

    expect(book).not_to be_valid
    expect(book.errors[:author]).to be_present
  end
end
