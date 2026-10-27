require "rails_helper"

RSpec.describe Reader, type: :model do
  def build_reader(**overrides)
    Reader.new({
      card_number: "000123",
      full_name: "Ada Lovelace",
      email: "ada@example.com"
    }.merge(overrides))
  end

  it "keeps a six-digit card number and downcases the email" do
    reader = build_reader(email: " Ada@Example.com ")

    expect(reader.save).to be(true)
    expect(reader.card_number).to eq("000123")
    expect(reader.email).to eq("ada@example.com")
  end

  it "rejects a card number that is not six digits" do
    reader = build_reader(card_number: "12345")

    expect(reader).not_to be_valid
    expect(reader.errors[:card_number]).to be_present
  end

  it "rejects a duplicate card number" do
    build_reader.save!

    duplicate = build_reader(email: "other@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:card_number]).to be_present
  end

  it "rejects a blank name" do
    reader = build_reader(full_name: "  ")

    expect(reader).not_to be_valid
    expect(reader.errors[:full_name]).to be_present
  end

  it "rejects an invalid email" do
    reader = build_reader(email: "not-an-email")

    expect(reader).not_to be_valid
    expect(reader.errors[:email]).to be_present
  end

  it "rejects the same email regardless of case" do
    build_reader.save!

    duplicate = build_reader(card_number: "000124", email: "ADA@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end
end
