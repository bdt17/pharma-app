require "test_helper"

class WarehouseIntegrationServiceTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "Test Region")
    @site = Site.create!(name: "Test Site", region: @region)
    @truck = Truck.create!(
      name: "Test Truck",
      site: @site,
      status: "active",
      min_temp: 2,
      max_temp: 8
    )
    @warehouse = Warehouse.create!(
      name: "Cold Storage A",
      code: "CSA001",
      warehouse_type: "cold_storage",
      status: "active",
      min_temp: 2,
      max_temp: 8,
      capacity_pallets: 100,
      current_occupancy: 50,
      latitude: 42.3601,
      longitude: -71.0589
    )
    @zone = @warehouse.storage_zones.create!(
      name: "Zone A",
      zone_type: "refrigerated",
      status: "active",
      min_temp: 2,
      max_temp: 8,
      capacity_pallets: 50,
      current_occupancy: 20
    )
  end

  test "find_nearest_cold_storage returns closest warehouse" do
    # Create another warehouse further away
    Warehouse.create!(
      name: "Cold Storage B",
      code: "CSB001",
      warehouse_type: "cold_storage",
      status: "active",
      capacity_pallets: 100,
      latitude: 34.0522,
      longitude: -118.2437
    )

    result = WarehouseIntegrationService.find_nearest_cold_storage(
      latitude: 42.3601,
      longitude: -71.0589
    )

    assert_equal @warehouse.id, result.id
  end

  test "find_nearest_cold_storage respects capacity requirement" do
    @warehouse.update!(current_occupancy: 100) # Full

    result = WarehouseIntegrationService.find_nearest_cold_storage(
      latitude: 42.3601,
      longitude: -71.0589,
      min_capacity: 10
    )

    assert_nil result
  end

  test "check_in_truck creates appointment" do
    result = WarehouseIntegrationService.check_in_truck(
      truck: @truck,
      warehouse: @warehouse,
      dock_number: "D1"
    )

    assert result[:success]
    assert_equal "D1", result[:dock_number]
    assert_equal @warehouse.name, result[:warehouse]

    appointment = @warehouse.dock_appointments.last
    assert_equal "arrived", appointment.status
    assert_equal @truck.id, appointment.truck_id
  end

  test "check_in_truck uses existing scheduled appointment" do
    existing = @warehouse.dock_appointments.create!(
      truck: @truck,
      appointment_type: "inbound",
      scheduled_at: 1.hour.from_now,
      status: "scheduled"
    )

    result = WarehouseIntegrationService.check_in_truck(
      truck: @truck,
      warehouse: @warehouse
    )

    assert result[:success]
    assert_equal existing.id, result[:appointment].id
    assert_equal "arrived", existing.reload.status
  end

  test "check_out_truck completes appointment" do
    @warehouse.dock_appointments.create!(
      truck: @truck,
      appointment_type: "inbound",
      scheduled_at: 1.hour.ago,
      arrived_at: 30.minutes.ago,
      status: "arrived"
    )

    result = WarehouseIntegrationService.check_out_truck(
      truck: @truck,
      warehouse: @warehouse
    )

    assert result[:success]
    assert result[:dwell_time_minutes].present?
  end

  test "transfer_inventory creates items in zone" do
    items = [
      {
        product_name: "Vaccine A",
        lot_number: "LOT001",
        quantity: 10,
        temperature_requirements: "refrigerated"
      }
    ]

    result = WarehouseIntegrationService.transfer_inventory(
      from_truck: @truck,
      to_zone: @zone,
      items: items
    )

    assert result[:success]
    assert_equal 1, result[:transferred_count]
    assert_equal "Vaccine A", @zone.inventory_items.last.product_name
  end

  test "transfer_inventory rejects incompatible temperature requirements" do
    frozen_zone = @warehouse.storage_zones.create!(
      name: "Frozen Zone",
      zone_type: "frozen",
      status: "active",
      min_temp: -25,
      max_temp: -15,
      capacity_pallets: 20
    )

    items = [
      {
        product_name: "Refrigerated Med",
        lot_number: "LOT002",
        quantity: 5,
        temperature_requirements: "ambient" # Not suitable for frozen
      }
    ]

    # Actually, ambient can go in frozen - let's test with a zone that won't accept
    # the requirement
    ambient_zone = @warehouse.storage_zones.create!(
      name: "Ambient Zone",
      zone_type: "ambient",
      status: "active",
      capacity_pallets: 20
    )

    frozen_items = [
      {
        product_name: "Frozen Med",
        lot_number: "LOT003",
        quantity: 5,
        temperature_requirements: "frozen"
      }
    ]

    result = WarehouseIntegrationService.transfer_inventory(
      from_truck: @truck,
      to_zone: ambient_zone,
      items: frozen_items
    )

    assert_not result[:success]
    assert result[:errors].any?
  end

  test "warehouse_status returns comprehensive data" do
    @zone.inventory_items.create!(
      product_name: "Test Product",
      lot_number: "LOT001",
      quantity: 10,
      status: "available",
      arrival_time: Time.current
    )

    status = WarehouseIntegrationService.warehouse_status(@warehouse)

    assert_equal @warehouse.id, status[:warehouse_id]
    assert_equal @warehouse.name, status[:name]
    assert status[:occupancy].present?
    assert status[:zones].is_a?(Array)
    assert status[:today_appointments].present?
    assert status[:alerts].is_a?(Array)
  end

  test "handoff_report generates truck-warehouse report" do
    @warehouse.dock_appointments.create!(
      truck: @truck,
      appointment_type: "inbound",
      scheduled_at: 1.hour.ago,
      arrived_at: 30.minutes.ago,
      dock_number: "D3",
      status: "arrived"
    )

    report = WarehouseIntegrationService.handoff_report(
      truck: @truck,
      warehouse: @warehouse
    )

    assert report[:truck].present?
    assert report[:warehouse].present?
    assert report[:handoff].present?
    assert report[:chain_of_custody].present?
    assert_equal @truck.id, report[:truck][:id]
    assert_equal @warehouse.id, report[:warehouse][:id]
  end
end
