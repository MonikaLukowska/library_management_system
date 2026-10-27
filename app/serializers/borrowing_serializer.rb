class BorrowingSerializer
  attr_reader :borrowing

  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json(*)
    {
      borrowed_on: borrowing.borrowed_on,
      due_on: borrowing.due_on,
      returned_on: borrowing.returned_on,
      reader: ReaderSerializer.new(borrowing.reader).as_json
    }
  end
end
