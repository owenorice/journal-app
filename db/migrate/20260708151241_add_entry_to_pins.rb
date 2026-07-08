class AddEntryToPins < ActiveRecord::Migration[8.1]
  def change
    add_reference :pins, :entry, null: false, foreign_key: true
  end
end
