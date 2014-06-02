class AddAncestryToAlbum < ActiveRecord::Migration
  def change
    add_column :albums, :ancestry, :string
    add_index :albums, :ancestry
  end
end
