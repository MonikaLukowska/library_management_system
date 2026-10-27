class BookSerializer
  attr_reader :book

  def initialize(book)
    @book = book
  end

  def as_json(*)
    base.merge(status: book.status)
  end

  def extended_as_json
    base.merge(
      borrowings: book.borrowings.map { |borrowing| BorrowingSerializer.new(borrowing).as_json }
    )
  end

  def self.many(books)
    books.map { |book| new(book).as_json }
  end

  private

    def base
      {
        serial_number: book.serial_number,
        title: book.title,
        author: book.author
      }
    end
end
