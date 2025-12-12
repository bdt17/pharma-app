class NetworkPlanner
  class << self
    def generate_plan(name:, start_date:, end_date:, created_by: nil)
      plan = CapacityPlan.create!(
        name: name,
        plan_start_date: start_date,
        plan_end_date: end_date,
        status: 'draft',
        created_by: created_by
      )

      analyze_lane_capacity(plan, start_date, end_date)
      analyze_node_capacity(plan, start_date, end_date)
      analyze_regional_demand(plan, start_date, end_date)

      generate_recommendations(plan)

      plan.reload
    end

    def analyze_demand_vs_capacity(region_id: nil, site_id: nil, start_date: nil, end_date: nil)
      start_date ||= Date.current
      end_date ||= 30.days.from_now.to_date

      forecasts = DemandForecast.for_date_range(start_date, end_date)
      forecasts = forecasts.for_region(region_id) if region_id
      forecasts = forecasts.for_site(site_id) if site_id

      total_demand = forecasts.sum(:forecast_quantity)

      capacities = LaneCapacity.active.current
      total_capacity = capacities.sum(:shipments_per_day) * (end_date - start_date).to_i

      gap = total_demand - total_capacity
      utilization = total_capacity.positive? ? (total_demand.to_f / total_capacity * 100).round(2) : 0

      {
        period: { start_date: start_date, end_date: end_date },
        total_demand: total_demand,
        total_capacity: total_capacity,
        capacity_gap: gap,
        utilization_percent: utilization,
        status: capacity_status(utilization),
        by_product: demand_by_product(forecasts),
        by_region: demand_by_region(forecasts)
      }
    end

    def suggest_shipments_per_lane(start_date: nil, end_date: nil)
      start_date ||= Date.current
      end_date ||= 7.days.from_now.to_date
      days = (end_date - start_date).to_i

      lanes = LaneCapacity.active.current
      forecasts = DemandForecast.for_date_range(start_date, end_date)

      suggestions = lanes.map do |lane|
        demand = estimate_lane_demand(lane, forecasts)
        daily_demand = days.positive? ? (demand.to_f / days).ceil : 0

        {
          lane_code: lane.lane_code,
          carrier: lane.carrier_name,
          transport_mode: lane.transport_mode,
          daily_capacity: lane.daily_capacity,
          suggested_daily_shipments: [daily_demand, lane.daily_capacity].min,
          excess_demand: [daily_demand - lane.daily_capacity, 0].max,
          utilization_percent: lane.daily_capacity.positive? ? (daily_demand.to_f / lane.daily_capacity * 100).round(2) : 0,
          recommendation: lane_recommendation(daily_demand, lane.daily_capacity)
        }
      end

      {
        period: { start_date: start_date, end_date: end_date },
        lanes: suggestions,
        summary: summarize_lane_suggestions(suggestions)
      }
    end

    def identify_capacity_upgrades
      lanes = LaneCapacity.active.current
      nodes = NodeCapacity.active.current

      upgrades = []

      lanes.each do |lane|
        if lane_needs_upgrade?(lane)
          upgrades << {
            type: 'lane',
            code: lane.lane_code,
            current_capacity: lane.daily_capacity,
            recommended_increase: calculate_lane_increase(lane),
            priority: 'high',
            reason: 'Projected demand exceeds capacity'
          }
        end
      end

      nodes.each do |node|
        if node_needs_upgrade?(node)
          upgrades << {
            type: 'node',
            name: node.name,
            current_capacity: node.storage_capacity_pallets,
            recommended_increase: calculate_node_increase(node),
            priority: node.utilization_percent.to_f > 95 ? 'critical' : 'high',
            reason: 'Storage utilization exceeds threshold'
          }
        end
      end

      upgrades.sort_by { |u| u[:priority] == 'critical' ? 0 : 1 }
    end

    def identify_additional_carriers
      lanes_needing_carriers = []

      LaneCapacity.active.current.each do |lane|
        forecasts = DemandForecast.future.limit(30)
        demand = estimate_lane_demand(lane, forecasts)

        if demand > lane.daily_capacity * 30
          lanes_needing_carriers << {
            lane_code: lane.lane_code,
            current_carrier: lane.carrier_name,
            current_capacity: lane.daily_capacity,
            projected_demand_30d: demand,
            gap: demand - (lane.daily_capacity * 30),
            recommendation: 'Add additional carrier or increase frequency'
          }
        end
      end

      lanes_needing_carriers
    end

    def regional_summary
      Region.all.map do |region|
        forecasts = DemandForecast.for_region(region.id).future
        total_demand = forecasts.sum(:forecast_quantity)

        node_caps = NodeCapacity.active.current.joins("INNER JOIN sites ON node_capacities.capacitable_type = 'Site' AND node_capacities.capacitable_id = sites.id").where(sites: { region_id: region.id })
        total_capacity = node_caps.sum(:storage_capacity_pallets)

        {
          region_id: region.id,
          region_name: region.name,
          forecast_demand: total_demand,
          node_capacity: total_capacity,
          gap: total_demand - total_capacity,
          status: total_capacity >= total_demand ? 'adequate' : 'constrained'
        }
      end
    end

    private

    def analyze_lane_capacity(plan, start_date, end_date)
      LaneCapacity.active.current.find_each do |lane|
        forecasts = DemandForecast.for_date_range(start_date, end_date)
        demand = estimate_lane_demand(lane, forecasts)
        days = (end_date - start_date).to_i
        capacity = lane.daily_capacity * days
        gap = demand - capacity
        utilization = capacity.positive? ? (demand.to_f / capacity * 100).round(2) : 0

        plan.capacity_plan_items.create!(
          item_type: 'lane',
          lane_code: lane.lane_code,
          forecast_demand: demand,
          available_capacity: capacity,
          capacity_gap: [gap, 0].max,
          utilization_percent: utilization,
          priority: gap_priority(gap, utilization),
          recommendation: lane_recommendation(demand, capacity)
        )
      end
    end

    def analyze_node_capacity(plan, start_date, end_date)
      NodeCapacity.active.current.find_each do |node|
        plan.capacity_plan_items.create!(
          item_type: 'node',
          forecast_demand: node.throughput_per_day.to_i * (end_date - start_date).to_i,
          available_capacity: node.storage_capacity_pallets,
          capacity_gap: 0,
          utilization_percent: node.utilization_percent,
          priority: node.utilization_percent.to_f > 90 ? 'high' : 'low',
          recommendation: node.utilization_percent.to_f > 90 ? 'increase_capacity' : 'no_action'
        )
      end
    end

    def analyze_regional_demand(plan, start_date, end_date)
      Region.find_each do |region|
        forecasts = DemandForecast.for_region(region.id).for_date_range(start_date, end_date)
        demand = forecasts.sum(:forecast_quantity)

        plan.capacity_plan_items.create!(
          item_type: 'region',
          region: region,
          forecast_demand: demand,
          available_capacity: 0,
          capacity_gap: 0,
          utilization_percent: 0,
          priority: 'low',
          recommendation: 'no_action'
        )
      end
    end

    def generate_recommendations(plan)
      recommendations = []

      high_util_lanes = plan.capacity_plan_items.by_type('lane').where('utilization_percent > 90')
      if high_util_lanes.any?
        recommendations << "#{high_util_lanes.count} lane(s) operating above 90% capacity - consider adding carriers"
      end

      gaps = plan.capacity_plan_items.with_gap
      if gaps.any?
        total_gap = gaps.sum(:capacity_gap)
        recommendations << "Total capacity gap of #{total_gap} units identified across #{gaps.count} items"
      end

      critical = plan.capacity_plan_items.critical
      if critical.any?
        recommendations << "#{critical.count} critical capacity constraint(s) require immediate attention"
      end

      plan.update!(
        recommendations: recommendations.to_json,
        summary: "Plan covers #{plan.duration_days} days with #{plan.capacity_plan_items.count} items analyzed"
      )
    end

    def estimate_lane_demand(lane, forecasts)
      forecasts.sum(:forecast_quantity) / [LaneCapacity.active.count, 1].max
    end

    def lane_needs_upgrade?(lane)
      lane.shipments_per_day.to_i > 0 && estimate_future_demand(lane) > lane.daily_capacity * 30
    end

    def node_needs_upgrade?(node)
      node.utilization_percent.to_f > 85
    end

    def calculate_lane_increase(lane)
      current = lane.daily_capacity
      (current * 0.25).ceil
    end

    def calculate_node_increase(node)
      current = node.storage_capacity_pallets.to_i
      (current * 0.20).ceil
    end

    def estimate_future_demand(lane)
      DemandForecast.future.limit(30).sum(:forecast_quantity) / [LaneCapacity.active.count, 1].max
    end

    def capacity_status(utilization)
      case utilization
      when 0..70 then 'available'
      when 70..90 then 'moderate'
      when 90..100 then 'constrained'
      else 'over_capacity'
      end
    end

    def gap_priority(gap, utilization)
      return 'critical' if utilization > 100
      return 'high' if gap > 0 && utilization > 90
      return 'medium' if gap > 0 && utilization > 80
      'low'
    end

    def lane_recommendation(demand, capacity)
      return 'no_action' if demand <= capacity * 0.8
      return 'optimize_routing' if demand <= capacity
      return 'add_carrier' if demand <= capacity * 1.2
      'increase_capacity'
    end

    def demand_by_product(forecasts)
      forecasts.group(:product_code).sum(:forecast_quantity)
    end

    def demand_by_region(forecasts)
      forecasts.joins(:region).group('regions.name').sum(:forecast_quantity)
    end

    def summarize_lane_suggestions(suggestions)
      {
        total_lanes: suggestions.count,
        over_capacity: suggestions.count { |s| s[:excess_demand] > 0 },
        under_utilized: suggestions.count { |s| s[:utilization_percent] < 50 },
        optimal: suggestions.count { |s| s[:utilization_percent].between?(50, 90) }
      }
    end
  end
end
