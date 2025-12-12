class CreatePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :packages do |t|
      t.string :lane
      t.string :qualification_status
      t.references :truck, null: false, foreign_key: true

      t.timestamps
    end
  end
end
