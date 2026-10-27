class BookSerializer
  def initialize(book)
    @book = book
  end

  def as_json(*)
    {
      serial_number: book.serial_number,
      title: book.title,
      author: book.author
    }
  end

  def self.many(books)
    books.map { |book| new(book).as_json }
  end

  private
    attr_reader :book
end
