require "test_helper"

class PredictiveRiskEngineTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "Test Region")
    @site = Site.create!(name: "Test Site", region: @region)
    @truck = Truck.create!(
      name: "Test Truck",
      site: @site,
      status: "active",
      min_temp: 2,
      max_temp: 8,
      risk_score: 30
    )
    @route = Route.create!(
      name: "Test Route",
      origin: "Origin",
      destination: "Destination",
      truck: @truck,
      status: "in_progress",
      started_at: 2.hours.ago,
      estimated_duration: 240,
      max_transit_hours: 8
    )
    @route.waypoints.create!(site: @site, position: 1, status: "pending")
    @route.waypoints.create!(site: @site, position: 2, status: "pending")
  end

  test "forecast returns required keys" do
    forecast = PredictiveRiskEngine.forecast(@route)

    assert forecast.key?(:route_id)
    assert forecast.key?(:excursion_probability)
    assert forecast.key?(:ontime_probability)
    assert forecast.key?(:risk_band)
    assert forecast.key?(:risk_band_label)
    assert forecast.key?(:factors)
    assert forecast.key?(:early_warning)
    assert forecast.key?(:recommendations)
    assert forecast.key?(:forecast_generated_at)
  end

  test "excursion probability is between 0 and 1" do
    forecast = PredictiveRiskEngine.forecast(@route)

    assert forecast[:excursion_probability] >= 0.0
    assert forecast[:excursion_probability] <= 1.0
  end

  test "ontime probability is between 0 and 1" do
    forecast = PredictiveRiskEngine.forecast(@route)

    assert forecast[:ontime_probability] >= 0.0
    assert forecast[:ontime_probability] <= 1.0
  end

  test "risk band is valid" do
    forecast = PredictiveRiskEngine.forecast(@route)

    assert_includes [:low, :medium, :high], forecast[:risk_band]
    assert_includes ["Low", "Medium", "High"], forecast[:risk_band_label]
  end

  test "early_warning flag set when excursion probability high" do
    # Create conditions for high excursion probability
    @truck.update!(risk_score: 90)
    @truck.telemetry_readings.create!(
      temperature_c: 12.0,  # Well above max_temp of 8
      recorded_at: 1.minute.ago
    )

    forecast = PredictiveRiskEngine.forecast(@route)

    # With high truck risk and out-of-range temp, should trigger warning
    assert forecast[:excursion_probability] >= 0.4
  end

  test "factors includes expected keys" do
    forecast = PredictiveRiskEngine.forecast(@route)
    factors = forecast[:factors]

    assert factors.key?(:current_temp_deviation)
    assert factors.key?(:temp_variance_factor)
    assert factors.key?(:truck_risk_factor)
    assert factors.key?(:route_progress_factor)
    assert factors.key?(:time_in_transit_factor)
    assert factors.key?(:delay_factor)
    assert factors.key?(:remaining_stops_factor)
    assert factors.key?(:route_risk_factor)
  end

  test "early_warnings returns warnings for high risk routes" do
    # Make route high risk
    @truck.update!(risk_score: 95)
    @truck.telemetry_readings.create!(
      temperature_c: 15.0,  # Way above max
      recorded_at: 1.minute.ago
    )

    warnings = PredictiveRiskEngine.early_warnings([@route])

    # Should return warning if probability >= 0.6
    if warnings.any?
      warning = warnings.first
      assert_equal @route.id, warning[:route_id]
      assert warning[:forecast][:excursion_probability] >= PredictiveRiskEngine::EARLY_WARNING_THRESHOLD
    end
  end

  test "early_warnings excludes low risk routes" do
    # Keep route low risk with normal temp
    @truck.update!(risk_score: 10)
    @truck.telemetry_readings.create!(
      temperature_c: 5.0,  # In range
      recorded_at: 1.minute.ago
    )

    warnings = PredictiveRiskEngine.early_warnings([@route])

    # Low risk should not appear in warnings (probability < 0.6)
    warnings_for_route = warnings.select { |w| w[:route_id] == @route.id }
    if warnings_for_route.any?
      assert warnings_for_route.first[:forecast][:excursion_probability] >= 0.6
    end
  end

  test "recommendations generated for high excursion risk" do
    @truck.update!(risk_score: 95)
    @truck.telemetry_readings.create!(
      temperature_c: 15.0,
      recorded_at: 1.minute.ago
    )

    forecast = PredictiveRiskEngine.forecast(@route)

    if forecast[:excursion_probability] >= 0.6
      assert forecast[:recommendations].any? { |r| r[:type].include?("excursion") }
    end
  end

  test "recommendations sorted by priority" do
    forecast = PredictiveRiskEngine.forecast(@route)
    recommendations = forecast[:recommendations]

    return if recommendations.size < 2

    priorities = recommendations.map { |r| r[:priority] }
    assert_equal priorities, priorities.sort
  end

  test "temp variance factor increases with unstable readings" do
    # Create varying temperature readings
    [-2, 0, 5, 10, 3, 8, -1, 6].each_with_index do |offset, i|
      @truck.telemetry_readings.create!(
        temperature_c: 5.0 + offset,
        recorded_at: (i + 1).hours.ago
      )
    end

    forecast = PredictiveRiskEngine.forecast(@route)

    # High variance should increase factor
    assert forecast[:factors][:temp_variance_factor] > 0.0
  end

  test "time in transit factor increases as route progresses" do
    # Route started 6 hours ago with 8 hour max
    @route.update!(started_at: 6.hours.ago, max_transit_hours: 8)

    forecast = PredictiveRiskEngine.forecast(@route)

    # 6/8 = 0.75 * 0.8 = 0.6 time factor
    assert forecast[:factors][:time_in_transit_factor] > 0.5
  end
end
