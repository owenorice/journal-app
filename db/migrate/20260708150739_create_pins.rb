class CreatePins < ActiveRecord::Migration[8.1]
  def change
    create_table :pins do |t|
      t.float :x_percent, null: false
      t.float :y_percent, null: false
      t.string :label

      t.timestamps
    end
  end
end
