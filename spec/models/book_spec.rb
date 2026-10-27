require "rails_helper"

RSpec.describe Book, type: :model do
  it "keeps a six-digit serial number" do
    book = build(:book, serial_number: "000123")

    expect(book.save).to be(true)
    expect(book.serial_number).to eq("000123")
  end

  it "rejects a serial number that is not six digits" do
    book = build(:book, serial_number: "12345")

    expect(book).not_to be_valid
    expect(book.errors[:serial_number]).to be_present
  end

  it "rejects a duplicate serial number" do
    existing = create(:book)
    duplicate = build(:book, serial_number: existing.serial_number)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:serial_number]).to be_present
  end

  it "rejects a blank title" do
    book = build(:book, title: "  ")

    expect(book).not_to be_valid
    expect(book.errors[:title]).to be_present
  end

  it "rejects a blank author" do
    book = build(:book, author: "  ")

    expect(book).not_to be_valid
    expect(book.errors[:author]).to be_present
  end
end
