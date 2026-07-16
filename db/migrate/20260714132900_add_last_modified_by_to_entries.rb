class AddLastModifiedByToEntries < ActiveRecord::Migration[8.1]
  def change
    add_reference :entries, :last_modified_by, foreign_key: { to_table: :users }
  end
end
