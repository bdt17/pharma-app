require "test_helper"

class ShipmentEventTest < ActiveSupport::TestCase
  setup do
    @truck = trucks(:one)
  end

  test "valid event with required fields" do
    event = ShipmentEvent.new(
      truck: @truck,
      event_type: "route_started",
      recorded_at: Time.current
    )
    assert event.valid?
  end

  test "invalid without event_type" do
    event = ShipmentEvent.new(
      truck: @truck,
      recorded_at: Time.current
    )
    assert_not event.valid?
  end

  test "invalid with unknown event_type" do
    event = ShipmentEvent.new(
      truck: @truck,
      event_type: "unknown_type",
      recorded_at: Time.current
    )
    assert_not event.valid?
  end

  test "invalid without recorded_at" do
    event = ShipmentEvent.new(
      truck: @truck,
      event_type: "route_started"
    )
    assert_not event.valid?
  end

  test "log_event creates event with defaults" do
    event = ShipmentEvent.log_event(
      truck: @truck,
      event_type: "manual_check",
      description: "Visual inspection"
    )
    assert event.persisted?
    assert_not_nil event.recorded_at
  end

  test "chain hash links to previous event" do
    # Clear existing events for this truck
    ShipmentEvent.where(truck: @truck).destroy_all

    event1 = ShipmentEvent.create!(
      truck: @truck,
      event_type: "route_started",
      recorded_at: 1.hour.ago
    )
    assert_nil event1.previous_hash # First event has no previous

    event2 = ShipmentEvent.create!(
      truck: @truck,
      event_type: "stop_arrival",
      recorded_at: Time.current
    )
    assert_equal event1.compute_hash, event2.previous_hash
  end

  test "verify_chain returns valid for correct chain" do
    # Use a different truck to avoid fixture interference
    truck2 = trucks(:two)
    ShipmentEvent.where(truck: truck2).destroy_all

    ShipmentEvent.create!(truck: truck2, event_type: "route_started", recorded_at: 2.hours.ago)
    ShipmentEvent.create!(truck: truck2, event_type: "stop_arrival", recorded_at: 1.hour.ago)
    ShipmentEvent.create!(truck: truck2, event_type: "stop_departure", recorded_at: Time.current)

    result = ShipmentEvent.verify_chain(truck2.id)
    assert result[:valid]
    assert_equal 3, result[:events]
  end

  test "metadata can be stored as json" do
    event = ShipmentEvent.create!(
      truck: @truck,
      event_type: "manual_check",
      recorded_at: Time.current
    )
    event.metadata_hash = { inspector: "John Doe", notes: "All clear" }
    event.save!

    event.reload
    assert_equal "John Doe", event.parsed_metadata["inspector"]
  end
end
