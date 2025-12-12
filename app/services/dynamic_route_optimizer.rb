class DynamicRouteOptimizer
  SENSITIVITY_WEIGHTS = {
    'critical' => 2.0,
    'high' => 1.5,
    'standard' => 1.0,
    'low' => 0.5
  }.freeze

  PRIORITY_MULTIPLIER = 0.1

  def self.recommend(candidate_routes, constraints = {})
    new(candidate_routes, constraints).recommend
  end

  def self.score_route(route, constraints = {})
    new([route], constraints).score_single(route)
  end

  def initialize(candidate_routes, constraints = {})
    @candidates = candidate_routes
    @constraints = {
      max_risk: constraints[:max_risk] || 80,
      max_hours: constraints[:max_hours],
      max_cost: constraints[:max_cost],
      prefer_carrier: constraints[:prefer_carrier],
      time_window_start: constraints[:time_window_start],
      time_window_end: constraints[:time_window_end],
      optimize_for: constraints[:optimize_for] || 'balanced'
    }
  end

  def recommend
    scored = @candidates.map do |route|
      {
        route: route,
        scores: score_single(route),
        eligible: eligible?(route),
        tradeoffs: compute_tradeoffs(route)
      }
    end

    eligible_routes = scored.select { |r| r[:eligible] }
    ineligible_routes = scored.reject { |r| r[:eligible] }

    sorted = eligible_routes.sort_by { |r| -r[:scores][:overall] }

    {
      recommended: sorted.first,
      alternatives: sorted.drop(1),
      ineligible: ineligible_routes,
      optimization_mode: @constraints[:optimize_for],
      constraints_applied: @constraints
    }
  end

  def score_single(route)
    risk_score = compute_risk_score(route)
    time_score = compute_time_score(route)
    cost_score = compute_cost_score(route)
    priority_score = compute_priority_score(route)

    weights = optimization_weights
    overall = (
      risk_score * weights[:risk] +
      time_score * weights[:time] +
      cost_score * weights[:cost] +
      priority_score * weights[:priority]
    ).round(2)

    {
      overall: overall,
      risk: risk_score,
      time: time_score,
      cost: cost_score,
      priority: priority_score,
      breakdown: {
        risk_weight: weights[:risk],
        time_weight: weights[:time],
        cost_weight: weights[:cost],
        priority_weight: weights[:priority]
      }
    }
  end

  private

  def eligible?(route)
    return false if route_risk(route) > @constraints[:max_risk]

    if @constraints[:max_hours] && route.estimated_duration
      return false if (route.estimated_duration / 60.0) > @constraints[:max_hours]
    end

    if @constraints[:max_cost] && route.cost_estimate
      return false if route.cost_estimate > @constraints[:max_cost]
    end

    if @constraints[:time_window_end] && route.estimated_duration
      estimated_arrival = Time.current + route.estimated_duration.minutes
      return false if estimated_arrival > @constraints[:time_window_end]
    end

    true
  end

  def compute_risk_score(route)
    risk = route_risk(route)
    sensitivity = SENSITIVITY_WEIGHTS[route.temperature_sensitivity] || 1.0
    adjusted_risk = risk * sensitivity

    [100 - adjusted_risk, 0].max.round(2)
  end

  def compute_time_score(route)
    return 50 unless route.estimated_duration

    duration_hours = route.estimated_duration / 60.0
    max_hours = route.max_transit_hours || @constraints[:max_hours] || 24

    if duration_hours <= max_hours * 0.5
      100
    elsif duration_hours <= max_hours * 0.75
      80
    elsif duration_hours <= max_hours
      60
    elsif duration_hours <= max_hours * 1.25
      40
    else
      20
    end
  end

  def compute_cost_score(route)
    return 50 unless route.cost_estimate

    max_cost = @constraints[:max_cost] || 10000
    ratio = route.cost_estimate / max_cost

    if ratio <= 0.5
      100
    elsif ratio <= 0.75
      80
    elsif ratio <= 1.0
      60
    elsif ratio <= 1.25
      40
    else
      20
    end
  end

  def compute_priority_score(route)
    priority = route.priority || 5
    (priority * 10).clamp(0, 100)
  end

  def route_risk(route)
    route.risk_score rescue 0
  end

  def compute_tradeoffs(route)
    tradeoffs = []

    risk = route_risk(route)
    duration = route.estimated_duration || 0
    cost = route.cost_estimate || 0

    if risk > 60
      tradeoffs << {
        factor: 'risk',
        severity: risk > 80 ? 'high' : 'medium',
        message: "Route has elevated risk (#{risk})"
      }
    end

    if route.max_transit_hours && duration > route.max_transit_hours * 60
      tradeoffs << {
        factor: 'time',
        severity: 'high',
        message: "Exceeds max transit time by #{((duration / 60.0) - route.max_transit_hours).round(1)} hours"
      }
    end

    if @constraints[:max_cost] && cost > @constraints[:max_cost]
      tradeoffs << {
        factor: 'cost',
        severity: 'medium',
        message: "Exceeds budget by #{(cost - @constraints[:max_cost]).round(2)}"
      }
    end

    if route.temperature_sensitivity == 'critical' && risk > 40
      tradeoffs << {
        factor: 'sensitivity',
        severity: 'high',
        message: "Critical sensitivity product on route with risk #{risk}"
      }
    end

    tradeoffs
  end

  def optimization_weights
    case @constraints[:optimize_for]
    when 'risk'
      { risk: 0.6, time: 0.2, cost: 0.1, priority: 0.1 }
    when 'time'
      { risk: 0.2, time: 0.6, cost: 0.1, priority: 0.1 }
    when 'cost'
      { risk: 0.2, time: 0.2, cost: 0.5, priority: 0.1 }
    else
      { risk: 0.35, time: 0.30, cost: 0.20, priority: 0.15 }
    end
  end
end
