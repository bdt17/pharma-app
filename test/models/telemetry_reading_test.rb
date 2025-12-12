require "test_helper"

class TelemetryReadingTest < ActiveSupport::TestCase
  setup do
    @truck = trucks(:one)
  end

  test "valid with location data" do
    reading = TelemetryReading.new(
      truck: @truck,
      latitude: 42.3601,
      longitude: -71.0589,
      recorded_at: Time.current
    )
    assert reading.valid?
  end

  test "valid with sensor data" do
    reading = TelemetryReading.new(
      truck: @truck,
      temperature_c: 5.5,
      recorded_at: Time.current
    )
    assert reading.valid?
  end

  test "invalid without location or sensor data" do
    reading = TelemetryReading.new(
      truck: @truck,
      recorded_at: Time.current
    )
    assert_not reading.valid?
    assert_includes reading.errors[:base], "Must have location (lat/lng) or at least one sensor reading"
  end

  test "invalid without recorded_at" do
    reading = TelemetryReading.new(
      truck: @truck,
      temperature_c: 5.5
    )
    assert_not reading.valid?
  end

  test "out_of_range returns true when temperature exceeds max" do
    @truck.update!(min_temp: 2, max_temp: 8)
    reading = TelemetryReading.new(
      truck: @truck,
      temperature_c: 15.0,
      recorded_at: Time.current
    )
    assert reading.out_of_range?
  end

  test "out_of_range returns false when temperature is in range" do
    @truck.update!(min_temp: 2, max_temp: 8)
    reading = TelemetryReading.new(
      truck: @truck,
      temperature_c: 5.0,
      recorded_at: Time.current
    )
    assert_not reading.out_of_range?
  end
end
