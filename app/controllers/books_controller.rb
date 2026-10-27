class BooksController < ApplicationController
  def index
    render json: BookSerializer.many(Book.order(:serial_number))
  end

  def create
    book = Book.new(book_params)

    if book.save
      render json: BookSerializer.new(book).as_json, status: :created
    else
      render json: { errors: book.errors }, status: :unprocessable_content
    end
  end

  def destroy
    Book.find_by!(serial_number: params[:serial_number]).destroy!
    head :no_content
  end

  private

    def book_params
      params.permit(:serial_number, :title, :author)
    end
end
