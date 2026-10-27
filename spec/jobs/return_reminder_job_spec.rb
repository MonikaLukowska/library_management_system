require "rails_helper"

RSpec.describe ReturnReminderJob, type: :job do
  def create_loan
    book = Book.create!(serial_number: "000123", title: "Dune", author: "Frank Herbert")
    reader = Reader.create!(card_number: "000123", full_name: "Ada Lovelace", email: "ada@example.com")
    Borrowing.create!(book: book, reader: reader, borrowed_on: Date.new(2026, 10, 27), due_on: Date.new(2026, 11, 26))
  end

  def logged_messages
    messages = []
    allow(Rails.logger).to receive(:info).and_wrap_original do |method, message = nil, &block|
      messages << (message || block&.call)
      method.call(message, &block)
    end
    yield
    messages
  end

  it "logs the due reminder for an open loan" do
    loan = create_loan

    messages = logged_messages do
      described_class.perform_now(loan.id, loan.due_on, ReturnReminderJob::DUE)
    end

    expect(messages).to include(
      "Email to=ada@example.com subject=Book due today: Dune body=Dear Ada Lovelace, \"Dune\" (000123) is due today, 2026-11-26."
    )
  end

  it "logs the upcoming reminder three days before the due date" do
    loan = create_loan

    messages = logged_messages do
      described_class.perform_now(loan.id, loan.due_on, ReturnReminderJob::UPCOMING)
    end

    expect(messages).to include(
      "Email to=ada@example.com subject=Book due in 3 days: Dune body=Dear Ada Lovelace, \"Dune\" (000123) is due in 3 days, on 2026-11-26."
    )
  end

  it "does not log when the book has been returned" do
    loan = create_loan
    loan.update!(returned_on: Date.new(2026, 11, 1))

    messages = logged_messages do
      described_class.perform_now(loan.id, loan.due_on, ReturnReminderJob::DUE)
    end

    expect(messages).not_to include(a_string_starting_with("Email to="))
  end

  it "does not log when the due date no longer matches" do
    loan = create_loan

    messages = logged_messages do
      described_class.perform_now(loan.id, loan.due_on + 1, ReturnReminderJob::UPCOMING)
    end

    expect(messages).not_to include(a_string_starting_with("Email to="))
  end

  it "does nothing when the loan no longer exists" do
    messages = logged_messages do
      described_class.perform_now(0, Date.new(2026, 11, 26), ReturnReminderJob::DUE)
    end

    expect(messages).not_to include(a_string_starting_with("Email to="))
  end
end
