# Library management system

Staff JSON API for a small library. It keeps a catalog of books, lends a copy out for 30 days, records the full loan history, and schedules a return reminder three days before the due date and again on the due date.

Ruby 4.0.7, Rails 8.1, PostgreSQL 17. There is no authentication: the API assumes a trusted staff client.

## Run with Docker

```sh
docker compose up --build
```

## Run locally

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

## API

Requests and responses are flat JSON. A missing book returns 404. Invalid input returns 422 with an `errors` object. Create returns 201. Delete returns 204.

| Method   | Path                    | Purpose                                                           |
| -------- | ----------------------- | ----------------------------------------------------------------- |
| `GET`    | `/books`                | Catalog, ordered by serial number, with `available` or `borrowed` |
| `GET`    | `/books/:serial_number` | One book and its loan history                                     |
| `POST`   | `/books`                | Add a book                                                        |
| `PATCH`  | `/books/:serial_number` | Borrow or return                                                  |
| `DELETE` | `/books/:serial_number` | Remove a book that has never been borrowed                        |

The public id is `serial_number`, a six-digit string. Leading zeros are part of the value.

## Reminders

Borrowing a book enqueues two `ReturnReminderJob`s: one on `due_on - 3 days`, one on `due_on`. Each waits until midnight of that date in the application time zone (UTC by default). The loan period is 30 days, so a borrow on 27 October is due on 26 November, with reminders on 23 and 26 November.

When a job runs it loads the loan again. It logs an email payload only if that loan still exists, is still open, and still has the due date that was current when the job was scheduled. Otherwise it returns without logging.

Nothing is sent over SMTP. In development the queue is the in-memory `:async` adapter, so a restart drops jobs that have not run. Run one immediately and read the log inside the container:

```sh
docker compose exec web bin/rails runner \
  'loan = Borrowing.where(returned_on: nil).first; ReturnReminderJob.perform_now(loan.id, loan.due_on, "due")'

docker compose exec web tail -n 20 log/development.log
```

Locally the same line is in `log/development.log`. Production uses Solid Queue and a separate queue database, so a scheduled reminder survives a restart there.

## Tests

```sh
bin/rails db:test:prepare && bin/rspec
bin/rubocop
```

## Design notes

**Availability is a loan, not a column.** `books` stores `serial_number`, `title`, and `author`. A book is `borrowed` when it has a borrowing with `returned_on` nil, and `available` otherwise. A partial unique index on `borrowings.book_id WHERE returned_on IS NULL` makes a second open loan impossible even if two requests arrive together. `ChangeBookStatus` turns that database error into the same 422 the happy path uses. Returning sets `returned_on` and leaves the row in place, which is what `GET /books/:serial_number` lists.

**The list and the detail are different documents.** `GET /books` preloads the open loan and returns serial number, title, author, and status. `GET /books/:serial_number` preloads every loan with its reader and returns the history: borrow date, return date, and the reader's card, name, and email. `due_on` is stored because the reminder schedule needs it; the detail response described in the task does not include it. Create, borrow, and return respond with the short shape, including the new status.

**Identifiers stay strings.** Serial numbers and card numbers are six digits with a unique index. Keeping them as strings preserves leading zeros, which a numeric column would drop. The numeric primary key stays in the database and is omitted from JSON. Routes look up books with `param: :serial_number`.

**Author and reader name stay single columns.** The catalog is small and the API never filters or edits an author or a name on its own, so `author` and `full_name` are plain strings. Email is stripped and downcased in `before_validation`, so the uniqueness validation and the unique index see the same value.

**Status changes live in one object.** `BooksController` finds the book and renders JSON. `ChangeBookStatus` borrows, returns, and enqueues reminders. After creating or closing a loan it resets the cached `open_borrowing` on the book object it was given, so a caller that keeps that object sees the new status before the controller reloads for the response.

**A returned book does not cancel its jobs.** The scheduled jobs stay in the queue. At run time the returned loan fails the "still open" check and the job logs nothing. A later loan is a new row with a new id, so the old jobs cannot attach to it. The due-date argument is a second guard for a loan whose `due_on` changed after scheduling. The API has no action that edits `due_on` today.

**Deleting history is refused.** `dependent: :restrict_with_error` on a book's borrowings (and a reader's) stops a destroy that would orphan or erase loans. The controller renders those errors as 422.

## Limitations and possible next steps

- No authentication, and `config/initializers/cors.rb` does not allow any browser origin. Both match the current staff-only scope. A real frontend needs an origin list, and anything beyond a trusted network needs auth.
- Readers can only be created from seeds or the console. A staff screen for cards would need a readers API.
- Reminder delivery is a log line. The job already rebuilds the recipient, subject, and body, so swapping `Rails.logger.info` for a mailer is local to `ReturnReminderJob` once SMTP exists.
- In development, reminders live only as long as the web process does. Discarding the jobs when a book comes back would keep the queue smaller. Running Solid Queue as its own Compose service would make the long waits observable locally.
- `due_on` is invisible to API clients. Adding it to the history payload is the smallest way to show a due date in a staff UI.
- The catalog endpoint returns every book in one array, in serial-number order, with no title or author search. That is cheap at this size. Pagination, and an index chosen for the actual search, belong with a larger catalog.
