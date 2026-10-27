class ChangeBookStatus
  attr_reader :book, :status, :card_number

  def self.call(book, status:, card_number:)
    new(book, status:, card_number:).call
  end

  def initialize(book, status:, card_number:)
    @book = book
    @status = status
    @card_number = card_number
  end

  def call
    case status
    when "borrowed" then borrow
    when "available" then make_available
    else
      book.errors.add(:status, "must be borrowed or available")
      false
    end
  end

  private

    def borrow
      reader = Reader.find_by(card_number: card_number)

      if reader.nil?
        book.errors.add(:card_number, "does not match a reader")
        return false
      end

      if book.open_borrowing
        book.errors.add(:base, "Book is already borrowed")
        return false
      end

      book.borrowings.create!(reader:, borrowed_on: Date.current, due_on:).tap do |loan|
        book.association(:open_borrowing).reset
        schedule_reminders(loan)
      end

      true
    rescue ActiveRecord::RecordInvalid => error
      book.errors.merge!(error.record.errors)
      false
    rescue ActiveRecord::RecordNotUnique
      book.errors.add(:base, "Book is already borrowed")
      false
    end

    def make_available
      loan = book.open_borrowing
      if loan.nil?
        book.errors.add(:base, "Book is already available")
        return false
      end

      loan.update!(returned_on: Date.current)
      book.association(:open_borrowing).reset
      true
    end

    def due_on
      Date.current + Borrowing::LOAN_PERIOD_IN_DAYS
    end

    def schedule_reminders(loan)
      enqueue_reminder(loan, loan.due_on - ReturnReminderJob::DAYS_BEFORE, ReturnReminderJob::UPCOMING)
      enqueue_reminder(loan, loan.due_on, ReturnReminderJob::DUE)
    end

    def enqueue_reminder(loan, on, kind)
      ReturnReminderJob.set(wait_until: on.in_time_zone).perform_later(loan.id, loan.due_on, kind)
    end
end
