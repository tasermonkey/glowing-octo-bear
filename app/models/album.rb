class Album < ActiveRecord::Base
  has_ancestry
  has_many :album_items
  has_many :photos, through: :album_items
end
