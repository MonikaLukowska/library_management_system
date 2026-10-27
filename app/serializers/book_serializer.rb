class BookSerializer
  attr_reader :book, :history

  def initialize(book, history: false)
    @book = book
    @history = history
  end

  def as_json(*)
    loan = book.current_borrowing

    data = {
      serial_number: book.serial_number,
      title: book.title,
      author: book.author,
      status: book.status,
      borrowed_on: loan&.borrowed_on,
      reader: loan && ReaderSerializer.new(loan.reader).as_json
    }

    data[:borrowings] = book.borrowings.map { |borrowing| BorrowingSerializer.new(borrowing).as_json } if history
    data
  end

  def self.many(books)
    books.map { |book| new(book).as_json }
  end
end
