class AddWateringAndNotesToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :watering_frequency, :integer
    add_column :entries, :notes, :text
  end
end
