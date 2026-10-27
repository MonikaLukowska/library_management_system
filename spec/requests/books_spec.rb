require "rails_helper"

RSpec.describe "Books", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def book_json(book, status: "available")
    {
      "serial_number" => book.serial_number,
      "title" => book.title,
      "author" => book.author,
      "status" => status
    }
  end

  def reader_json(reader)
    {
      "card_number" => reader.card_number,
      "full_name" => reader.full_name,
      "email" => reader.email
    }
  end

  describe "GET /books" do
    it "returns books ordered by serial number" do
      later = create(:book, serial_number: "000200", title: "Dune", author: "Frank Herbert")
      earlier = create(:book, serial_number: "000100", title: "Neuromancer", author: "William Gibson")

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        book_json(earlier),
        book_json(later)
      ])
    end

    it "shows whether a book is borrowed" do
      create(:book, serial_number: "000100")
      borrowed = create(:book, serial_number: "000200")

      ChangeBookStatus.call(borrowed, status: "borrowed", card_number: create(:reader).card_number)
      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |book| book["status"] }).to eq([ "available", "borrowed" ])
    end

    it "loads the list in a fixed number of queries" do
      books = create_list(:book, 3)
      ChangeBookStatus.call(books.first, status: "borrowed", card_number: create(:reader).card_number)

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
      book = create(:book)
      first_reader = create(:reader)
      second_reader = create(:reader)

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
        "serial_number" => book.serial_number,
        "title" => book.title,
        "author" => book.author,
        "borrowings" => [
          {
            "borrowed_on" => "2026-10-01",
            "returned_on" => "2026-10-20",
            "reader" => reader_json(first_reader)
          },
          {
            "borrowed_on" => "2026-10-27",
            "returned_on" => nil,
            "reader" => reader_json(second_reader)
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
      expect(response.parsed_body).to eq(
        "serial_number" => "000123",
        "title" => "Dune",
        "author" => "Frank Herbert",
        "status" => "available"
      )
      expect(Book.find_by(serial_number: "000123")).to be_present
    end

    it "rejects a serial number that is not six digits" do
      post "/books", params: { serial_number: "12345", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(0)
    end

    it "rejects a duplicate serial number" do
      book = create(:book)

      post "/books", params: { serial_number: book.serial_number, title: "Other", author: "Someone" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(1)
    end
  end

  describe "PATCH /books/:serial_number" do
    it "borrows a book for a reader" do
      book = create(:book)
      reader = create(:reader)

      travel_to Date.new(2026, 10, 27) do
        patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: reader.card_number }, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("borrowed")
      expect(book.borrowings.sole.due_on).to eq(Date.new(2026, 11, 26))
    end

    it "returns a borrowed book" do
      book = create(:book)
      ChangeBookStatus.call(book, status: "borrowed", card_number: create(:reader).card_number)

      patch "/books/#{book.serial_number}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("available")
      expect(book.borrowings.sole.returned_on).to eq(Date.current)
    end

    it "rejects borrowing when the reader does not exist" do
      book = create(:book)

      patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: "000999" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["card_number"]).to eq([ "does not match a reader" ])
      expect(book.borrowings).to be_empty
    end

    it "rejects borrowing a book that is already borrowed" do
      book = create(:book)
      ChangeBookStatus.call(book, status: "borrowed", card_number: create(:reader).card_number)

      patch "/books/#{book.serial_number}", params: { status: "borrowed", card_number: create(:reader).card_number }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["base"]).to eq([ "Book is already borrowed" ])
      expect(book.borrowings.count).to eq(1)
    end

    it "rejects returning a book that is available" do
      book = create(:book)

      patch "/books/#{book.serial_number}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["base"]).to eq([ "Book is already available" ])
    end

    it "rejects an unknown status" do
      book = create(:book)

      patch "/books/#{book.serial_number}", params: { status: "lost" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["status"]).to eq([ "must be borrowed or available" ])
    end
  end

  describe "DELETE /books/:serial_number" do
    it "deletes a book" do
      book = create(:book)

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:no_content)
      expect(Book.where(serial_number: book.serial_number)).to be_empty
    end

    it "rejects deleting a book that has borrowing history" do
      book = create(:book)
      ChangeBookStatus.call(book, status: "borrowed", card_number: create(:reader).card_number)

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
