class CreateAlbumItems < ActiveRecord::Migration
  def change
    create_table :album_items do |t|
      t.belongs_to :album
      t.belongs_to :photo
      t.integer :position
      t.timestamps
    end
  end
end
