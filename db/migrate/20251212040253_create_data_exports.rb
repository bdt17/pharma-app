class CreateDataExports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_exports do |t|
      t.string :format
      t.string :status
      t.string :url

      t.timestamps
    end
  end
end
