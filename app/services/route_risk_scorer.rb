class RouteRiskScorer
  RISK_THRESHOLDS = {
    low: 30,
    medium: 60,
    high: 80
  }.freeze

  def self.for_route(route)
    new(route).calculate
  end

  def self.suggest_action(route)
    new(route).suggest_action
  end

  def initialize(route)
    @route = route
  end

  def calculate
    factors = compute_factors
    score = weighted_score(factors)
    level = determine_level(score)

    {
      score: score,
      level: level,
      factors: factors,
      recommendations: generate_recommendations(factors, score)
    }
  end

  def suggest_action
    result = calculate
    {
      route_id: @route.id,
      route_name: @route.name,
      risk_score: result[:score],
      risk_level: result[:level],
      action: determine_action(result),
      recommendations: result[:recommendations],
      priority_stops: priority_stops
    }
  end

  private

  def compute_factors
    {
      truck_risk: truck_risk_factor,
      cargo_time: cargo_time_factor,
      pending_stops: pending_stops_factor,
      environmental: environmental_factor,
      historical: historical_factor
    }
  end

  def truck_risk_factor
    return 0 unless @route.truck.present?

    @route.truck.risk_score || 0
  end

  def cargo_time_factor
    return 0 unless @route.in_progress? && @route.started_at.present?

    hours_elapsed = (Time.current - @route.started_at) / 1.hour

    if hours_elapsed < 4
      0
    elsif hours_elapsed < 8
      (hours_elapsed - 4) * 10
    elsif hours_elapsed < 12
      40 + (hours_elapsed - 8) * 15
    else
      100
    end.clamp(0, 100)
  end

  def pending_stops_factor
    pending = @route.waypoints.pending.count
    total = @route.waypoints.count

    return 0 if total.zero?

    high_risk_pending = @route.waypoints.pending.count do |wp|
      wp.site_risk_level > 60
    end

    if high_risk_pending > 0
      50 + (high_risk_pending * 10)
    else
      (pending.to_f / total * 30).clamp(0, 100)
    end
  end

  def environmental_factor
    return 0 unless @route.truck.present?

    latest = @route.truck.latest_telemetry
    return 50 unless latest # No telemetry = moderate risk

    score = 0

    if latest.out_of_range?
      score += 60
    end

    if latest.temperature_c.present?
      temp_variance = calculate_temp_variance
      score += [temp_variance * 10, 30].min
    end

    hours_since = (Time.current - latest.recorded_at) / 1.hour if latest.recorded_at
    if hours_since && hours_since > 2
      score += [hours_since * 5, 30].min
    end

    score.clamp(0, 100)
  end

  def historical_factor
    return 0 unless @route.truck.present?

    completed_routes = Route.where(truck: @route.truck, status: 'completed')
                           .where("updated_at > ?", 30.days.ago)

    return 0 if completed_routes.empty?

    excursion_routes = completed_routes.joins(:waypoints)
                                       .where("waypoints.notes LIKE ?", "%excursion%")
                                       .distinct.count

    ratio = excursion_routes.to_f / completed_routes.count
    (ratio * 100).clamp(0, 100)
  end

  def calculate_temp_variance
    return 0 unless @route.truck.present?

    readings = @route.truck.telemetry_readings
                    .where("recorded_at > ?", 6.hours.ago)
                    .pluck(:temperature_c)
                    .compact

    return 0 if readings.size < 3

    mean = readings.sum / readings.size
    variance = readings.map { |t| (t - mean) ** 2 }.sum / readings.size
    Math.sqrt(variance)
  end

  def weighted_score(factors)
    weights = {
      truck_risk: 0.35,
      cargo_time: 0.20,
      pending_stops: 0.15,
      environmental: 0.20,
      historical: 0.10
    }

    score = factors.sum { |factor, value| value * weights[factor] }
    score.round.clamp(0, 100)
  end

  def determine_level(score)
    if score <= RISK_THRESHOLDS[:low]
      "low"
    elsif score <= RISK_THRESHOLDS[:medium]
      "medium"
    elsif score <= RISK_THRESHOLDS[:high]
      "high"
    else
      "critical"
    end
  end

  def determine_action(result)
    case result[:level]
    when "critical"
      { type: "IMMEDIATE_ACTION", message: "Route at critical risk. Consider stopping and assessing cargo integrity." }
    when "high"
      { type: "EXPEDITE", message: "High risk detected. Prioritize high-risk stops and expedite delivery." }
    when "medium"
      { type: "MONITOR", message: "Elevated risk. Monitor temperatures closely and consider reordering stops." }
    else
      { type: "PROCEED", message: "Route is within acceptable risk parameters. Continue as planned." }
    end
  end

  def generate_recommendations(factors, score)
    recommendations = []

    if factors[:truck_risk] > 60
      recommendations << {
        priority: 1,
        type: "truck_risk",
        message: "Truck has elevated risk score (#{factors[:truck_risk]}). Check recent temperature readings."
      }
    end

    if factors[:cargo_time] > 50
      recommendations << {
        priority: 1,
        type: "cargo_time",
        message: "Cargo has been in transit for extended period. Consider expediting remaining deliveries."
      }
    end

    if factors[:environmental] > 50
      recommendations << {
        priority: 2,
        type: "environmental",
        message: "Environmental conditions are concerning. Verify refrigeration unit is functioning properly."
      }
    end

    if factors[:pending_stops] > 40
      recommendations << {
        priority: 2,
        type: "pending_stops",
        message: "High-risk stops pending. Use 'reorder_by_risk' to prioritize critical deliveries."
      }
    end

    if score > 70 && @route.status == 'planned'
      recommendations << {
        priority: 1,
        type: "delay_start",
        message: "Consider delaying route start until truck risk levels decrease."
      }
    end

    recommendations.sort_by { |r| r[:priority] }
  end

  def priority_stops
    @route.waypoints.pending.includes(:site).map do |wp|
      risk = wp.site_risk_level
      next unless risk > 50

      {
        waypoint_id: wp.id,
        site_name: wp.site.name,
        position: wp.position,
        risk_score: risk,
        priority: risk > 70 ? "critical" : "elevated"
      }
    end.compact.sort_by { |s| -s[:risk_score] }
  end
end
