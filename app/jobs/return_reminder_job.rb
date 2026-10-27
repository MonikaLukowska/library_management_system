class ReturnReminderJob < ApplicationJob
  UPCOMING = "upcoming"
  DUE = "due"
  DAYS_BEFORE = 3

  def perform(borrowing_id, expected_due_on, kind)
    borrowing = Borrowing.includes(:reader, :book).find_by(id: borrowing_id)
    return if borrowing.nil? || borrowing.returned_on.present?
    return if borrowing.due_on != expected_due_on.to_date

    Rails.logger.info(email_payload(borrowing, kind))
  end

  private

    def email_payload(borrowing, kind)
      due_today = kind == DUE
      when_due = due_today ? "due today, #{borrowing.due_on}" : "due in 3 days, on #{borrowing.due_on}"
      subject = "#{due_today ? "Book due today" : "Book due in 3 days"}: #{borrowing.book.title}"

      "Email to=#{borrowing.reader.email} subject=#{subject} body=Dear #{borrowing.reader.full_name}, \"#{borrowing.book.title}\" (#{borrowing.book.serial_number}) is #{when_due}."
    end
end
