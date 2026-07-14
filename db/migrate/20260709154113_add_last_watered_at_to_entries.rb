class AddLastWateredAtToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :last_watered_at, :datetime
  end
end
