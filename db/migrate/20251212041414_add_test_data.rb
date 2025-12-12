class AddTestData < ActiveRecord::Migration[8.1]
  def up
    User.first_or_create!(email: 'demo@pharmatransport.com', password: 'password123')
    
    truck = Truck.create!(name: 'PharmaTruck-001', user: User.first)
    InventoryItem.create!(truck: truck, name: 'Insulin', quantity: 500, temp: 28.5, location: 'Bay A3', status: 'critical')
    Anomaly.create!(truck: truck, voltage_deviation: -15.2, temp_deviation: 8.5, severity: 'high')
    Rule.create!(condition: 'temp > 25', action: 'sms_alert', priority: 1, active: true)
  end
end
