require "test_helper"

class RiskScorerTest < ActiveSupport::TestCase
  setup do
    @truck = trucks(:one)
    @truck.update!(min_temp: 2, max_temp: 8)
  end

  test "returns zero score for truck with no monitorings" do
    @truck.monitorings.destroy_all
    result = RiskScorer.for_truck(@truck)

    assert_equal 0, result[:score]
    assert_equal "low", result[:level]
  end

  test "calculates low risk for truck with normal temperatures" do
    @truck.monitorings.destroy_all
    # Add recent readings within safe range
    3.times do |i|
      @truck.monitorings.create!(
        temperature: 5,
        power_status: "on",
        recorded_at: i.minutes.ago
      )
    end

    result = RiskScorer.for_truck(@truck)

    assert result[:score] <= 30, "Score should be low, got #{result[:score]}"
    assert_equal "low", result[:level]
  end

  test "calculates elevated risk for truck with excursions" do
    @truck.monitorings.destroy_all
    # Add readings that are out of range
    5.times do |i|
      @truck.monitorings.create!(
        temperature: 15, # Way above max_temp of 8
        power_status: "on",
        recorded_at: i.minutes.ago
      )
    end

    result = RiskScorer.for_truck(@truck)

    assert result[:score] > 30, "Score should be elevated, got #{result[:score]}"
    assert ["medium", "high", "critical"].include?(result[:level])
  end

  test "updates truck risk_score and risk_level" do
    @truck.monitorings.destroy_all
    @truck.monitorings.create!(
      temperature: 5,
      power_status: "on",
      recorded_at: 1.minute.ago
    )

    RiskScorer.for_truck(@truck)
    @truck.reload

    assert_not_nil @truck.risk_score
    assert_not_nil @truck.risk_level
  end

  test "recalculate_all processes all trucks" do
    Truck.update_all(risk_score: nil, risk_level: nil)

    RiskScorer.recalculate_all

    Truck.find_each do |truck|
      assert_not_nil truck.risk_score, "Truck #{truck.id} should have risk_score"
    end
  end
end
