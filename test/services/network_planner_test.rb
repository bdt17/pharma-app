require "test_helper"

class NetworkPlannerTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "Test Region")
    @site = Site.create!(name: "Test Site", region: @region)

    @lane = LaneCapacity.create!(
      lane_code: "LANE001",
      carrier_name: "Test Carrier",
      transport_mode: "truck",
      shipments_per_day: 10,
      status: "active"
    )

    @node = NodeCapacity.create!(
      name: "Test Node",
      capacitable: @site,
      storage_capacity_pallets: 1000,
      throughput_per_day: 100,
      utilization_percent: 75.0,
      status: "active"
    )

    @forecast = DemandForecast.create!(
      product_code: "PROD001",
      forecast_date: Date.current + 5.days,
      forecast_quantity: 500,
      period_type: "daily",
      region: @region
    )
  end

  test "generate_plan creates a capacity plan" do
    plan = NetworkPlanner.generate_plan(
      name: "Test Plan",
      start_date: Date.current,
      end_date: Date.current + 30.days,
      created_by: "test@example.com"
    )

    assert plan.persisted?
    assert_equal "Test Plan", plan.name
    assert_equal "draft", plan.status
    assert plan.capacity_plan_items.any?
  end

  test "analyze_demand_vs_capacity returns analysis hash" do
    result = NetworkPlanner.analyze_demand_vs_capacity

    assert result.is_a?(Hash)
    assert result.key?(:total_demand)
    assert result.key?(:total_capacity)
    assert result.key?(:capacity_gap)
    assert result.key?(:utilization_percent)
    assert result.key?(:status)
    assert result.key?(:by_product)
    assert result.key?(:by_region)
  end

  test "analyze_demand_vs_capacity filters by region" do
    result = NetworkPlanner.analyze_demand_vs_capacity(region_id: @region.id)

    assert result.is_a?(Hash)
    assert result[:total_demand] >= 0
  end

  test "suggest_shipments_per_lane returns lane suggestions" do
    result = NetworkPlanner.suggest_shipments_per_lane

    assert result.is_a?(Hash)
    assert result.key?(:period)
    assert result.key?(:lanes)
    assert result.key?(:summary)
    assert result[:lanes].is_a?(Array)
  end

  test "suggest_shipments_per_lane includes lane details" do
    result = NetworkPlanner.suggest_shipments_per_lane

    lane_suggestion = result[:lanes].find { |l| l[:lane_code] == "LANE001" }
    assert lane_suggestion.present?
    assert lane_suggestion.key?(:daily_capacity)
    assert lane_suggestion.key?(:suggested_daily_shipments)
    assert lane_suggestion.key?(:utilization_percent)
    assert lane_suggestion.key?(:recommendation)
  end

  test "identify_capacity_upgrades returns upgrades array" do
    result = NetworkPlanner.identify_capacity_upgrades

    assert result.is_a?(Array)
  end

  test "identify_capacity_upgrades flags high utilization nodes" do
    @node.update!(utilization_percent: 96.0)
    result = NetworkPlanner.identify_capacity_upgrades

    node_upgrade = result.find { |u| u[:type] == "node" && u[:name] == "Test Node" }
    assert node_upgrade.present?
    assert_equal "critical", node_upgrade[:priority]
  end

  test "identify_additional_carriers returns lanes needing carriers" do
    result = NetworkPlanner.identify_additional_carriers

    assert result.is_a?(Array)
  end

  test "regional_summary returns region summaries" do
    result = NetworkPlanner.regional_summary

    assert result.is_a?(Array)
    region_summary = result.find { |r| r[:region_id] == @region.id }
    assert region_summary.present?
    assert region_summary.key?(:forecast_demand)
    assert region_summary.key?(:node_capacity)
    assert region_summary.key?(:gap)
    assert region_summary.key?(:status)
  end

  test "capacity status based on utilization" do
    assert_equal "available", NetworkPlanner.send(:capacity_status, 50)
    assert_equal "moderate", NetworkPlanner.send(:capacity_status, 80)
    assert_equal "constrained", NetworkPlanner.send(:capacity_status, 95)
    assert_equal "over_capacity", NetworkPlanner.send(:capacity_status, 110)
  end

  test "lane recommendation based on demand vs capacity" do
    assert_equal "no_action", NetworkPlanner.send(:lane_recommendation, 70, 100)
    assert_equal "optimize_routing", NetworkPlanner.send(:lane_recommendation, 95, 100)
    assert_equal "add_carrier", NetworkPlanner.send(:lane_recommendation, 110, 100)
    assert_equal "increase_capacity", NetworkPlanner.send(:lane_recommendation, 150, 100)
  end

  test "gap priority calculation" do
    assert_equal "critical", NetworkPlanner.send(:gap_priority, 100, 110)
    assert_equal "high", NetworkPlanner.send(:gap_priority, 50, 95)
    assert_equal "medium", NetworkPlanner.send(:gap_priority, 30, 85)
    assert_equal "low", NetworkPlanner.send(:gap_priority, 0, 70)
  end
end
