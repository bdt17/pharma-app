class Api::V1::WarehousesController < Api::BaseController
  def index
    warehouses = Warehouse.includes(:storage_zones, :site).order(:name)
    warehouses = warehouses.where(status: params[:status]) if params[:status].present?
    warehouses = warehouses.where(warehouse_type: params[:type]) if params[:type].present?

    render json: warehouses.map { |w| serialize_warehouse(w) }
  end

  def show
    warehouse = Warehouse.find(params[:id])
    render json: WarehouseIntegrationService.warehouse_status(warehouse)
  end

  def create
    warehouse = Warehouse.new(warehouse_params)
    warehouse.status ||= 'active'

    if warehouse.save
      render json: serialize_warehouse(warehouse), status: :created
    else
      render json: { errors: warehouse.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def nearest
    unless params[:latitude].present? && params[:longitude].present?
      return render json: { error: 'latitude and longitude required' }, status: :bad_request
    end

    temp_range = if params[:min_temp].present? && params[:max_temp].present?
                   { min: params[:min_temp].to_f, max: params[:max_temp].to_f }
                 end

    warehouse = WarehouseIntegrationService.find_nearest_cold_storage(
      latitude: params[:latitude].to_f,
      longitude: params[:longitude].to_f,
      min_capacity: params[:min_capacity]&.to_i || 1,
      temp_range: temp_range
    )

    if warehouse
      render json: serialize_warehouse(warehouse)
    else
      render json: { error: 'No suitable warehouse found' }, status: :not_found
    end
  end

  def check_in
    warehouse = Warehouse.find(params[:id])
    truck = Truck.find(params[:truck_id])

    result = WarehouseIntegrationService.check_in_truck(
      truck: truck,
      warehouse: warehouse,
      dock_number: params[:dock_number]
    )

    render json: result
  end

  def check_out
    warehouse = Warehouse.find(params[:id])
    truck = Truck.find(params[:truck_id])

    result = WarehouseIntegrationService.check_out_truck(
      truck: truck,
      warehouse: warehouse
    )

    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def handoff
    warehouse = Warehouse.find(params[:id])
    truck = Truck.find(params[:truck_id])

    report = WarehouseIntegrationService.handoff_report(
      truck: truck,
      warehouse: warehouse
    )

    render json: report
  end

  def readings
    warehouse = Warehouse.find(params[:id])
    readings = warehouse.warehouse_readings.recent(params[:hours]&.to_i || 24)
    readings = readings.for_zone(params[:zone_id]) if params[:zone_id].present?
    readings = readings.order(recorded_at: :desc).limit(params[:limit] || 100)

    render json: readings.map { |r| serialize_reading(r) }
  end

  def record_reading
    warehouse = Warehouse.find(params[:id])

    reading = warehouse.warehouse_readings.new(reading_params)
    reading.recorded_at ||= Time.current

    if reading.save
      render json: serialize_reading(reading), status: :created
    else
      render json: { errors: reading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def appointments
    warehouse = Warehouse.find(params[:id])
    appointments = warehouse.dock_appointments.includes(:truck)

    appointments = appointments.where(status: params[:status]) if params[:status].present?
    appointments = appointments.where(appointment_type: params[:type]) if params[:type].present?

    if params[:date].present?
      date = Date.parse(params[:date])
      appointments = appointments.where(scheduled_at: date.beginning_of_day..date.end_of_day)
    else
      appointments = appointments.today.or(appointments.upcoming)
    end

    render json: appointments.order(scheduled_at: :asc).map { |a| serialize_appointment(a) }
  end

  def create_appointment
    warehouse = Warehouse.find(params[:id])

    appointment = warehouse.dock_appointments.new(appointment_params)
    appointment.status ||= 'scheduled'

    if appointment.save
      render json: serialize_appointment(appointment), status: :created
    else
      render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def warehouse_params
    params.require(:warehouse).permit(
      :name, :code, :warehouse_type, :address, :city, :state, :zip,
      :latitude, :longitude, :min_temp, :max_temp,
      :capacity_pallets, :current_occupancy, :status, :site_id
    )
  end

  def reading_params
    params.require(:reading).permit(:temperature, :humidity, :storage_zone_id, :sensor_id, :recorded_at)
  end

  def appointment_params
    params.require(:appointment).permit(:truck_id, :appointment_type, :scheduled_at, :dock_number, :notes)
  end

  def serialize_warehouse(warehouse)
    {
      id: warehouse.id,
      name: warehouse.name,
      code: warehouse.code,
      type: warehouse.warehouse_type,
      status: warehouse.status,
      address: warehouse.full_address,
      coordinates: warehouse.coordinates,
      temp_range: warehouse.min_temp && warehouse.max_temp ? "#{warehouse.min_temp}°C - #{warehouse.max_temp}°C" : nil,
      current_temperature: warehouse.current_temperature,
      temperature_status: warehouse.temperature_status,
      capacity: warehouse.capacity_pallets,
      occupancy: warehouse.current_occupancy,
      available_capacity: warehouse.available_capacity,
      occupancy_percentage: warehouse.occupancy_percentage,
      site_id: warehouse.site_id,
      site_name: warehouse.site&.name,
      zones_count: warehouse.storage_zones.count,
      created_at: warehouse.created_at,
      updated_at: warehouse.updated_at
    }
  end

  def serialize_reading(reading)
    {
      id: reading.id,
      warehouse_id: reading.warehouse_id,
      storage_zone_id: reading.storage_zone_id,
      temperature: reading.temperature,
      humidity: reading.humidity,
      sensor_id: reading.sensor_id,
      recorded_at: reading.recorded_at,
      in_range: reading.in_range?,
      deviation: reading.deviation
    }
  end

  def serialize_appointment(appointment)
    {
      id: appointment.id,
      warehouse_id: appointment.warehouse_id,
      truck_id: appointment.truck_id,
      truck_name: appointment.truck&.name,
      appointment_type: appointment.appointment_type,
      status: appointment.status,
      scheduled_at: appointment.scheduled_at,
      arrived_at: appointment.arrived_at,
      departed_at: appointment.departed_at,
      dock_number: appointment.dock_number,
      on_time: appointment.on_time?,
      dwell_time_minutes: appointment.dwell_time_minutes,
      notes: appointment.notes
    }
  end
end
