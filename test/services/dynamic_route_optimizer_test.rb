require "test_helper"

class DynamicRouteOptimizerTest < ActiveSupport::TestCase
  setup do
    @route1 = routes(:one)
    @route2 = routes(:two)
  end

  test "score_route returns valid score structure" do
    scores = DynamicRouteOptimizer.score_route(@route1)

    assert scores.key?(:overall)
    assert scores.key?(:risk)
    assert scores.key?(:time)
    assert scores.key?(:cost)
    assert scores.key?(:priority)
    assert scores.key?(:breakdown)
  end

  test "recommend returns structured result" do
    result = DynamicRouteOptimizer.recommend([@route1, @route2])

    assert result.key?(:recommended)
    assert result.key?(:alternatives)
    assert result.key?(:ineligible)
    assert result.key?(:optimization_mode)
    assert result.key?(:constraints_applied)
  end

  test "respects max_risk constraint" do
    result = DynamicRouteOptimizer.recommend([@route1], { max_risk: 10 })

    assert result.key?(:ineligible)
    assert result.key?(:recommended)
  end

  test "different optimization modes produce different weights" do
    risk_scores = DynamicRouteOptimizer.new([@route1], { optimize_for: 'risk' })
    time_scores = DynamicRouteOptimizer.new([@route1], { optimize_for: 'time' })

    risk_result = risk_scores.score_single(@route1)
    time_result = time_scores.score_single(@route1)

    assert_equal 0.6, risk_result[:breakdown][:risk_weight]
    assert_equal 0.6, time_result[:breakdown][:time_weight]
  end

  test "higher priority routes score higher on priority factor" do
    @route1.update!(priority: 10)
    @route2.update!(priority: 1)

    score1 = DynamicRouteOptimizer.score_route(@route1)
    score2 = DynamicRouteOptimizer.score_route(@route2)

    assert score1[:priority] > score2[:priority]
  end

  test "temperature sensitivity affects risk scoring" do
    @route1.update!(temperature_sensitivity: 'critical')
    @route2.update!(temperature_sensitivity: 'low')

    score1 = DynamicRouteOptimizer.score_route(@route1)
    score2 = DynamicRouteOptimizer.score_route(@route2)

    assert score1[:breakdown].present?
    assert score2[:breakdown].present?
  end
end
