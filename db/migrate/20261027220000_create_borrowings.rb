class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true
      t.references :reader, null: false, foreign_key: true
      t.date :borrowed_on, null: false
      t.date :due_on, null: false
      t.date :returned_on

      t.timestamps
    end

    add_index :borrowings, :book_id, unique: true, where: "returned_on IS NULL", name: "index_open_borrowings_on_book_id"
  end
end
