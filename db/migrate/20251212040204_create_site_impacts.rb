class CreateSiteImpacts < ActiveRecord::Migration[8.1]
  def change
    create_table :site_impacts do |t|
      t.string :site_name
      t.decimal :impact_score
      t.integer :patients_affected

      t.timestamps
    end
  end
end
