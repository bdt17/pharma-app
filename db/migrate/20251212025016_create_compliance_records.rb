class CreateComplianceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :compliance_records do |t|
      t.string :record_type
      t.string :reference_id
      t.string :reference_type
      t.string :status
      t.text :requirements
      t.text :evidence
      t.string :verified_by
      t.datetime :verified_at
      t.datetime :expires_at
      t.text :notes

      t.timestamps
    end
  end
end
