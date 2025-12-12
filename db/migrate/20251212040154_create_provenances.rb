class CreateProvenances < ActiveRecord::Migration[8.1]
  def change
    create_table :provenances do |t|
      t.string :batch_id
      t.string :blockchain_hash
      t.boolean :verified

      t.timestamps
    end
  end
end
