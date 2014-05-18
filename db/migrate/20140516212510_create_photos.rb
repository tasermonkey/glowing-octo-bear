class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.string :original_filename
      t.string :name
      t.string :guid
      t.string :s3key
      t.datetime :date_time_original
      t.integer :width
      t.integer :height
      t.timestamps
    end
    add_index :photos, :guid, :unique => true
  end
end
