class WarehouseIntegrationService
  class << self
    def find_nearest_cold_storage(latitude:, longitude:, min_capacity: 1, temp_range: nil)
      new.find_nearest_cold_storage(latitude, longitude, min_capacity, temp_range)
    end

    def check_in_truck(truck:, warehouse:, dock_number: nil)
      new.check_in_truck(truck, warehouse, dock_number)
    end

    def check_out_truck(truck:, warehouse:)
      new.check_out_truck(truck, warehouse)
    end

    def transfer_inventory(from_truck:, to_zone:, items:)
      new.transfer_inventory(from_truck, to_zone, items)
    end

    def warehouse_status(warehouse)
      new.warehouse_status(warehouse)
    end

    def handoff_report(truck:, warehouse:)
      new.handoff_report(truck, warehouse)
    end
  end

  def find_nearest_cold_storage(latitude, longitude, min_capacity, temp_range)
    warehouses = Warehouse.active.cold_storage.with_capacity

    if temp_range
      warehouses = warehouses.where('min_temp <= ? AND max_temp >= ?', temp_range[:min], temp_range[:max])
    end

    warehouses = warehouses.select { |w| w.available_capacity.to_i >= min_capacity }

    return nil if warehouses.empty?

    warehouses.min_by do |w|
      next Float::INFINITY unless w.latitude && w.longitude
      haversine_distance(latitude, longitude, w.latitude.to_f, w.longitude.to_f)
    end
  end

  def check_in_truck(truck, warehouse, dock_number = nil)
    appointment = warehouse.dock_appointments
                          .pending
                          .where(truck_id: truck.id)
                          .order(scheduled_at: :asc)
                          .first

    if appointment
      appointment.arrive!
      appointment.update!(dock_number: dock_number) if dock_number
    else
      appointment = warehouse.dock_appointments.create!(
        truck: truck,
        appointment_type: 'inbound',
        scheduled_at: Time.current,
        arrived_at: Time.current,
        dock_number: dock_number,
        status: 'arrived'
      )
    end

    # Log shipment event
    truck.shipment_events.create!(
      event_type: 'geofence_enter',
      description: "Arrived at #{warehouse.name}",
      latitude: warehouse.latitude,
      longitude: warehouse.longitude,
      recorded_at: Time.current,
      recorded_by: 'system'
    ) if truck.respond_to?(:shipment_events)

    {
      success: true,
      appointment: appointment,
      dock_number: appointment.dock_number,
      warehouse: warehouse.name,
      on_time: appointment.on_time?
    }
  end

  def check_out_truck(truck, warehouse)
    appointment = warehouse.dock_appointments
                          .active
                          .where(truck_id: truck.id)
                          .first

    if appointment
      appointment.complete!

      # Log shipment event
      truck.shipment_events.create!(
        event_type: 'geofence_exit',
        description: "Departed from #{warehouse.name}",
        latitude: warehouse.latitude,
        longitude: warehouse.longitude,
        recorded_at: Time.current,
        recorded_by: 'system'
      ) if truck.respond_to?(:shipment_events)

      {
        success: true,
        appointment: appointment,
        dwell_time_minutes: appointment.dwell_time_minutes,
        warehouse: warehouse.name
      }
    else
      { success: false, error: 'No active appointment found' }
    end
  end

  def transfer_inventory(from_truck, to_zone, items)
    transferred = []
    errors = []

    items.each do |item_data|
      unless to_zone.suitable_for_product?(item_data[:temperature_requirements])
        errors << { item: item_data[:product_name], error: 'Zone not suitable for temperature requirements' }
        next
      end

      if to_zone.available_capacity.to_i < 1
        errors << { item: item_data[:product_name], error: 'Zone at capacity' }
        next
      end

      item = to_zone.inventory_items.create!(
        product_name: item_data[:product_name],
        lot_number: item_data[:lot_number],
        quantity: item_data[:quantity],
        unit: item_data[:unit] || 'pallets',
        arrival_time: Time.current,
        expiration_date: item_data[:expiration_date],
        temperature_requirements: item_data[:temperature_requirements],
        status: 'available'
      )

      to_zone.increment!(:current_occupancy, 1) if to_zone.current_occupancy

      transferred << item
    end

    {
      success: errors.empty?,
      transferred_count: transferred.size,
      transferred: transferred.map { |i| { id: i.id, product: i.product_name, lot: i.lot_number } },
      errors: errors
    }
  end

  def warehouse_status(warehouse)
    zones = warehouse.storage_zones.includes(:inventory_items, :warehouse_readings)

    {
      warehouse_id: warehouse.id,
      name: warehouse.name,
      code: warehouse.code,
      status: warehouse.status,
      current_temperature: warehouse.current_temperature,
      temperature_status: warehouse.temperature_status,
      occupancy: {
        total_capacity: warehouse.capacity_pallets,
        current: warehouse.current_occupancy,
        available: warehouse.available_capacity,
        percentage: warehouse.occupancy_percentage
      },
      zones: zones.map do |zone|
        {
          id: zone.id,
          name: zone.name,
          type: zone.zone_type,
          status: zone.status,
          temp_range: zone.temp_range_label,
          current_temperature: zone.current_temperature,
          temperature_status: zone.temperature_status,
          occupancy: {
            capacity: zone.capacity_pallets,
            current: zone.current_occupancy,
            available: zone.available_capacity,
            percentage: zone.occupancy_percentage
          },
          inventory_count: zone.inventory_items.available.count,
          expiring_soon: zone.inventory_items.expiring_soon.count
        }
      end,
      today_appointments: {
        total: warehouse.today_appointments.count,
        inbound: warehouse.today_appointments.inbound.count,
        outbound: warehouse.today_appointments.outbound.count,
        active: warehouse.dock_appointments.active.count
      },
      alerts: generate_warehouse_alerts(warehouse, zones)
    }
  end

  def handoff_report(truck, warehouse)
    appointment = warehouse.dock_appointments
                          .where(truck_id: truck.id)
                          .order(created_at: :desc)
                          .first

    truck_temp = truck.latest_telemetry&.temperature_c ||
                 truck.monitorings.order(recorded_at: :desc).first&.temperature
    warehouse_temp = warehouse.current_temperature

    temp_delta = if truck_temp && warehouse_temp
                   (truck_temp - warehouse_temp).abs.round(1)
                 end

    {
      timestamp: Time.current,
      truck: {
        id: truck.id,
        name: truck.name,
        temperature: truck_temp,
        temp_range: "#{truck.min_temp}°C - #{truck.max_temp}°C"
      },
      warehouse: {
        id: warehouse.id,
        name: warehouse.name,
        code: warehouse.code,
        temperature: warehouse_temp,
        temp_range: "#{warehouse.min_temp}°C - #{warehouse.max_temp}°C"
      },
      handoff: {
        appointment_id: appointment&.id,
        dock_number: appointment&.dock_number,
        arrived_at: appointment&.arrived_at,
        temperature_delta: temp_delta,
        temperature_compatible: temp_delta.nil? || temp_delta <= 3.0,
        on_time: appointment&.on_time?,
        dwell_time_minutes: appointment&.dwell_time_minutes
      },
      chain_of_custody: {
        continuous: temp_delta.nil? || temp_delta <= 3.0,
        notes: temp_delta && temp_delta > 3.0 ? "Temperature gap of #{temp_delta}°C detected" : nil
      }
    }
  end

  private

  def haversine_distance(lat1, lon1, lat2, lon2)
    rad_per_deg = Math::PI / 180
    earth_radius_km = 6371

    dlat = (lat2 - lat1) * rad_per_deg
    dlon = (lon2 - lon1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlon / 2)**2

    2 * earth_radius_km * Math.asin(Math.sqrt(a))
  end

  def generate_warehouse_alerts(warehouse, zones)
    alerts = []

    # Warehouse-level alerts
    if warehouse.temperature_status == 'too_hot'
      alerts << { level: 'critical', type: 'temperature', message: "Warehouse temperature above maximum" }
    elsif warehouse.temperature_status == 'too_cold'
      alerts << { level: 'warning', type: 'temperature', message: "Warehouse temperature below minimum" }
    end

    if warehouse.occupancy_percentage >= 95
      alerts << { level: 'warning', type: 'capacity', message: "Warehouse at #{warehouse.occupancy_percentage}% capacity" }
    end

    # Zone-level alerts
    zones.each do |zone|
      if zone.temperature_status == 'too_hot'
        alerts << { level: 'critical', type: 'temperature', zone: zone.name, message: "Zone #{zone.name} temperature above maximum" }
      elsif zone.temperature_status == 'too_cold'
        alerts << { level: 'warning', type: 'temperature', zone: zone.name, message: "Zone #{zone.name} temperature below minimum" }
      end

      expiring = zone.inventory_items.expiring_soon(7).count
      if expiring > 0
        alerts << { level: 'warning', type: 'expiration', zone: zone.name, message: "#{expiring} items expiring within 7 days in #{zone.name}" }
      end
    end

    alerts
  end
end
