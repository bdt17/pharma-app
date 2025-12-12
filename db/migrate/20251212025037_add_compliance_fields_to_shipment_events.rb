class AddComplianceFieldsToShipmentEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :shipment_events, :signature_required, :boolean
    add_column :shipment_events, :signature_captured, :boolean
    add_column :shipment_events, :witness_name, :string
    add_column :shipment_events, :compliance_notes, :text
    add_column :shipment_events, :deviation_reported, :boolean
    add_column :shipment_events, :deviation_justification, :text
  end
end
