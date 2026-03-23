class AddCoverPhotoBlobIdToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :cover_photo_blob_id, :bigint
  end
end
