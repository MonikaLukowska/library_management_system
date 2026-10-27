require "rails_helper"

RSpec.describe "Books", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def create_book(**overrides)
    Book.create!({ serial_number: "000123", title: "Dune", author: "Frank Herbert" }.merge(overrides))
  end

  def create_reader(**overrides)
    Reader.create!({ card_number: "000123", full_name: "Ada Lovelace", email: "ada@example.com" }.merge(overrides))
  end

  def available_book(serial_number:, title:, author:)
    {
      "serial_number" => serial_number,
      "title" => title,
      "author" => author,
      "status" => "available",
      "borrowed_on" => nil,
      "reader" => nil
    }
  end

  describe "GET /books" do
    it "returns books ordered by serial number" do
      create_book(serial_number: "000200", title: "Dune", author: "Frank Herbert")
      create_book(serial_number: "000100", title: "Neuromancer", author: "William Gibson")

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        available_book(serial_number: "000100", title: "Neuromancer", author: "William Gibson"),
        available_book(serial_number: "000200", title: "Dune", author: "Frank Herbert")
      ])
    end

    it "shows who has a borrowed book" do
      create_book(serial_number: "000100", title: "Neuromancer", author: "William Gibson")
      borrowed = create_book(serial_number: "000200", title: "Dune", author: "Frank Herbert")
      reader = create_reader

      travel_to Date.new(2026, 10, 27) do
        ChangeBookStatus.call(borrowed, status: "borrowed", card_number: reader.card_number)
        get "/books"
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.last).to eq(
        "serial_number" => "000200",
        "title" => "Dune",
        "author" => "Frank Herbert",
        "status" => "borrowed",
        "borrowed_on" => "2026-10-27",
        "reader" => {
          "card_number" => "000123",
          "full_name" => "Ada Lovelace",
          "email" => "ada@example.com"
        }
      )
    end

    it "loads the list in a fixed number of queries" do
      3.times do |index|
        create_book(serial_number: format("%06d", index + 1), title: "Title #{index}", author: "Author #{index}")
      end
      book = Book.find_by!(serial_number: "000001")
      ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)

      queries = []
      ActiveSupport::Notifications.subscribed(->(*, payload) {
        queries << payload[:sql] if payload[:sql].match?(/\ASELECT/i)
      }, "sql.active_record") do
        get "/books"
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(3)
      expect(queries.size).to be <= 3
    end
  end

  describe "GET /books/:serial_number" do
    it "returns the book with its borrowing history" do
      book = create_book
      first_reader = create_reader
      second_reader = create_reader(card_number: "000124", full_name: "Grace Hopper", email: "grace@example.com")

      travel_to Date.new(2026, 10, 1) do
        patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: first_reader.card_number }, as: :json
      end
      travel_to Date.new(2026, 10, 20) do
        patch "/books/#{book.serial_number}", params: { status: "available" }, as: :json
      end
      travel_to Date.new(2026, 10, 27) do
        patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: second_reader.card_number }, as: :json
      end

      queries = []
      ActiveSupport::Notifications.subscribed(->(*, payload) {
        queries << payload[:sql] if payload[:sql].match?(/\ASELECT/i)
      }, "sql.active_record") do
        get "/books/#{book.serial_number}"
      end

      expect(response).to have_http_status(:ok)
      expect(queries.size).to be <= 3
      expect(response.parsed_body).to eq(
        "serial_number" => "000123",
        "title" => "Dune",
        "author" => "Frank Herbert",
        "status" => "borrowed",
        "borrowed_on" => "2026-10-27",
        "reader" => {
          "card_number" => "000124",
          "full_name" => "Grace Hopper",
          "email" => "grace@example.com"
        },
        "borrowings" => [
          {
            "borrowed_on" => "2026-10-01",
            "due_on" => "2026-10-31",
            "returned_on" => "2026-10-20",
            "reader" => {
              "card_number" => "000123",
              "full_name" => "Ada Lovelace",
              "email" => "ada@example.com"
            }
          },
          {
            "borrowed_on" => "2026-10-27",
            "due_on" => "2026-11-26",
            "returned_on" => nil,
            "reader" => {
              "card_number" => "000124",
              "full_name" => "Grace Hopper",
              "email" => "grace@example.com"
            }
          }
        ]
      )
    end

    it "returns not found when the book does not exist" do
      get "/books/000999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /books" do
    it "creates a book" do
      post "/books", params: { serial_number: "000123", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(available_book(serial_number: "000123", title: "Dune", author: "Frank Herbert"))
      expect(Book.find_by(serial_number: "000123")).to be_present
    end

    it "rejects a serial number that is not six digits" do
      post "/books", params: { serial_number: "12345", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(0)
    end

    it "rejects a duplicate serial number" do
      create_book

      post "/books", params: { serial_number: "000123", title: "Other", author: "Someone" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(1)
    end
  end

  describe "PATCH /books/:serial_number" do
    it "borrows a book for a reader" do
      book = create_book
      reader = create_reader

      travel_to Date.new(2026, 10, 27) do
        patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: reader.card_number }, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("borrowed")
      expect(book.borrowings.sole.due_on).to eq(Date.new(2026, 11, 26))
    end

    it "returns a borrowed book" do
      book = create_book
      ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)

      patch "/books/#{book.serial_number}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("available")
      expect(response.parsed_body["reader"]).to be_nil
      expect(book.borrowings.sole.returned_on).to eq(Date.current)
    end

    it "rejects borrowing when the reader does not exist" do
      book = create_book

      patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: "000999" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["card_number"]).to eq([ "does not match a reader" ])
      expect(book.borrowings).to be_empty
    end

    it "rejects borrowing a book that is already borrowed" do
      book = create_book
      ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)
      other = create_reader(card_number: "000124", full_name: "Grace Hopper", email: "grace@example.com")

      patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: other.card_number }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["base"]).to eq([ "Book is already borrowed" ])
      expect(book.borrowings.count).to eq(1)
    end

    it "rejects returning a book that is available" do
      book = create_book

      patch "/books/#{book.serial_number}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["base"]).to eq([ "Book is already available" ])
    end

    it "rejects an unknown status" do
      book = create_book

      patch "/books/#{book.serial_number}", params: { status: "lost" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["status"]).to eq([ "must be borrowed or available" ])
    end
  end

  describe "DELETE /books/:serial_number" do
    it "deletes a book" do
      create_book

      delete "/books/000123"

      expect(response).to have_http_status(:no_content)
      expect(Book.where(serial_number: "000123")).to be_empty
    end

    it "rejects deleting a book that has borrowing history" do
      book = create_book
      ChangeBookStatus.call(book, status: "borrowed", card_number: create_reader.card_number)

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.where(serial_number: book.serial_number)).to exist
    end

    it "returns not found when the book does not exist" do
      delete "/books/000999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
