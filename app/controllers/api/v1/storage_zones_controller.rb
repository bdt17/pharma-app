class Api::V1::StorageZonesController < Api::BaseController
  before_action :set_warehouse
  before_action :set_zone, only: [:show, :update, :inventory, :transfer]

  def index
    zones = @warehouse.storage_zones.includes(:inventory_items)
    zones = zones.where(zone_type: params[:type]) if params[:type].present?
    zones = zones.where(status: params[:status]) if params[:status].present?

    render json: zones.map { |z| serialize_zone(z) }
  end

  def show
    render json: serialize_zone(@zone, include_inventory: true)
  end

  def create
    zone = @warehouse.storage_zones.new(zone_params)
    zone.status ||= 'active'

    if zone.save
      render json: serialize_zone(zone), status: :created
    else
      render json: { errors: zone.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @zone.update(zone_params)
      render json: serialize_zone(@zone)
    else
      render json: { errors: @zone.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def inventory
    items = @zone.inventory_items
    items = items.where(status: params[:status]) if params[:status].present?
    items = items.expiring_soon(params[:expiring_days]&.to_i || 30) if params[:expiring_soon] == 'true'

    render json: items.map { |i| serialize_item(i) }
  end

  def transfer
    unless params[:items].present?
      return render json: { error: 'items array required' }, status: :bad_request
    end

    from_truck = params[:truck_id].present? ? Truck.find(params[:truck_id]) : nil

    result = WarehouseIntegrationService.transfer_inventory(
      from_truck: from_truck,
      to_zone: @zone,
      items: params[:items].map(&:to_unsafe_h)
    )

    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:warehouse_id])
  end

  def set_zone
    @zone = @warehouse.storage_zones.find(params[:id])
  end

  def zone_params
    params.require(:zone).permit(:name, :zone_type, :min_temp, :max_temp, :capacity_pallets, :status)
  end

  def serialize_zone(zone, include_inventory: false)
    data = {
      id: zone.id,
      warehouse_id: zone.warehouse_id,
      name: zone.name,
      type: zone.zone_type,
      status: zone.status,
      temp_range: zone.temp_range_label,
      min_temp: zone.min_temp,
      max_temp: zone.max_temp,
      current_temperature: zone.current_temperature,
      temperature_status: zone.temperature_status,
      capacity: zone.capacity_pallets,
      occupancy: zone.current_occupancy,
      available_capacity: zone.available_capacity,
      occupancy_percentage: zone.occupancy_percentage,
      inventory_count: zone.inventory_items.available.count,
      expiring_soon_count: zone.inventory_items.expiring_soon.count
    }

    if include_inventory
      data[:inventory] = zone.inventory_items.available.limit(50).map { |i| serialize_item(i) }
    end

    data
  end

  def serialize_item(item)
    {
      id: item.id,
      product_name: item.product_name,
      lot_number: item.lot_number,
      quantity: item.quantity,
      unit: item.unit,
      status: item.status,
      temperature_requirements: item.temperature_requirements,
      arrival_time: item.arrival_time,
      expiration_date: item.expiration_date,
      days_until_expiration: item.days_until_expiration,
      expired: item.expired?,
      expiring_soon: item.expiring_soon?,
      in_correct_zone: item.in_correct_zone?,
      dwell_time_hours: item.dwell_time_hours
    }
  end
end
