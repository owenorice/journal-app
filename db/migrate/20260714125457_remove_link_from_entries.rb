class RemoveLinkFromEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :entries, :link, :string
  end
end
