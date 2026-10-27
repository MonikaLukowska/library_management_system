class BooksController < ApplicationController
  def index
    books = Book.includes(:open_borrowing).order(:serial_number)
    render json: BookSerializer.many(books)
  end

  def show
    book = Book.includes(borrowings: :reader).find_by!(serial_number: params[:serial_number])
    render json: BookSerializer.new(book).extended_as_json
  end

  def create
    book = Book.new(book_params)

    if book.save
      render json: BookSerializer.new(book).as_json, status: :created
    else
      render json: { errors: book.errors }, status: :unprocessable_content
    end
  end

  def update
    book = find_book

    if ChangeBookStatus.call(book, status: params[:status], card_number: params[:card_number])
      render json: BookSerializer.new(book.reload).as_json
    else
      render json: { errors: book.errors }, status: :unprocessable_content
    end
  end

  def destroy
    book = find_book

    if book.destroy
      head :no_content
    else
      render json: { errors: book.errors }, status: :unprocessable_content
    end
  end

  private

    def find_book
      Book.find_by!(serial_number: params[:serial_number])
    end

    def book_params
      params.permit(:serial_number, :title, :author)
    end
end
