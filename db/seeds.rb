# Development catalog so the API can lend books without a readers endpoint.
# Borrowings are inserted directly and do not schedule reminder jobs.
# Running this again does nothing once any book or reader exists.

READER_PROFILES = [
  [ "Ada Lovelace", "ada@example.com" ],
  [ "Grace Hopper", "grace@example.com" ],
  [ "Alan Turing", "alan@example.com" ],
  [ "Katherine Johnson", "katherine@example.com" ],
  [ "Edsger Dijkstra", "edsger@example.com" ],
  [ "Barbara Liskov", "barbara@example.com" ],
  [ "Donald Knuth", "donald@example.com" ],
  [ "Margaret Hamilton", "margaret@example.com" ]
].freeze

BOOK_PROFILES = [
  [ "Dune", "Frank Herbert" ],
  [ "Neuromancer", "William Gibson" ],
  [ "The Left Hand of Darkness", "Ursula K. Le Guin" ],
  [ "Foundation", "Isaac Asimov" ],
  [ "Kindred", "Octavia E. Butler" ],
  [ "The Dispossessed", "Ursula K. Le Guin" ],
  [ "Snow Crash", "Neal Stephenson" ],
  [ "Parable of the Sower", "Octavia E. Butler" ],
  [ "The Handmaid's Tale", "Margaret Atwood" ],
  [ "Never Let Me Go", "Kazuo Ishiguro" ],
  [ "Piranesi", "Susanna Clarke" ],
  [ "Circe", "Madeline Miller" ]
].freeze

if Rails.env.development? && !Book.exists? && !Reader.exists?
  readers = READER_PROFILES.each_with_index.map do |(full_name, email), index|
    FactoryBot.create(:reader, card_number: format("%06d", index + 1), full_name:, email:)
  end
  books = BOOK_PROFILES.each_with_index.map do |(title, author), index|
    FactoryBot.create(:book, serial_number: format("%06d", index + 1), title:, author:)
  end

  books.first(4).zip(readers).each do |book, reader|
    FactoryBot.create(:borrowing, book:, reader:)
  end

  FactoryBot.create(:borrowing, :returned, book: books[4], reader: readers[4])

  FactoryBot.create(
    :borrowing,
    :returned,
    book: books[5],
    reader: readers[5],
    borrowed_on: Date.current - 90,
    due_on: Date.current - 60,
    returned_on: Date.current - 70
  )
  FactoryBot.create(:borrowing, book: books[5], reader: readers[6], borrowed_on: Date.current - 6)
end
