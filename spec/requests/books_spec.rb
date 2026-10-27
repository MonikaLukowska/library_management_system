require "rails_helper"

RSpec.describe "Books", type: :request do
  describe "GET /books" do
    it "returns books ordered by serial number" do
      Book.create!(serial_number: "000200", title: "Dune", author: "Frank Herbert")
      Book.create!(serial_number: "000100", title: "Neuromancer", author: "William Gibson")

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        { "serial_number" => "000100", "title" => "Neuromancer", "author" => "William Gibson" },
        { "serial_number" => "000200", "title" => "Dune", "author" => "Frank Herbert" }
      ])
    end
  end

  describe "POST /books" do
    it "creates a book" do
      post "/books", params: { serial_number: "000123", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(
        "serial_number" => "000123",
        "title" => "Dune",
        "author" => "Frank Herbert"
      )
      expect(Book.find_by(serial_number: "000123")).to be_present
    end

    it "rejects a serial number that is not six digits" do
      post "/books", params: { serial_number: "12345", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(0)
    end

    it "rejects a duplicate serial number" do
      Book.create!(serial_number: "000123", title: "Dune", author: "Frank Herbert")

      post "/books", params: { serial_number: "000123", title: "Other", author: "Someone" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Book.count).to eq(1)
    end
  end

  describe "DELETE /books/:serial_number" do
    it "deletes a book" do
      Book.create!(serial_number: "000123", title: "Dune", author: "Frank Herbert")

      delete "/books/000123"

      expect(response).to have_http_status(:no_content)
      expect(Book.where(serial_number: "000123")).to be_empty
    end

    it "returns not found when the book does not exist" do
      delete "/books/000999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
