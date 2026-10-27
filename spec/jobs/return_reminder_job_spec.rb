require "rails_helper"

RSpec.describe ReturnReminderJob, type: :job do
  def create_loan
    create(:borrowing, borrowed_on: Date.new(2026, 10, 27), due_on: Date.new(2026, 11, 26))
  end

  def reminder_for(loan, kind)
    due_today = kind == ReturnReminderJob::DUE
    when_due = due_today ? "due today, 2026-11-26" : "due in 3 days, on 2026-11-26"
    subject = "#{due_today ? "Book due today" : "Book due in 3 days"}: #{loan.book.title}"

    "Email to=#{loan.reader.email} subject=#{subject} body=Dear #{loan.reader.full_name}, \"#{loan.book.title}\" (#{loan.book.serial_number}) is #{when_due}."
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

    expect(messages).to include(reminder_for(loan, ReturnReminderJob::DUE))
  end

  it "logs the upcoming reminder three days before the due date" do
    loan = create_loan

    messages = logged_messages do
      described_class.perform_now(loan.id, loan.due_on, ReturnReminderJob::UPCOMING)
    end

    expect(messages).to include(reminder_for(loan, ReturnReminderJob::UPCOMING))
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
