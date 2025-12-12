class Api::V1::RoutesController < Api::BaseController
  def index
    routes = Route.includes(:truck, waypoints: :site).order(created_at: :desc)
    render json: routes.map { |r| serialize_route(r) }
  end

  def show
    route = Route.includes(:truck, waypoints: :site).find(params[:id])
    render json: serialize_route(route, include_waypoints: true)
  end

  def create
    route = Route.new(route_params)
    route.status = 'draft'

    if route.save
      create_waypoints(route)
      render json: serialize_route(route, include_waypoints: true), status: :created
    else
      render json: { errors: route.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def optimize
    route = Route.find(params[:id])
    RouteOptimizer.optimize(route)
    render json: {
      message: "Route optimized",
      route: serialize_route(route.reload, include_waypoints: true)
    }
  end

  def reorder_by_risk
    route = Route.find(params[:id])
    RouteOptimizer.new(route).reorder_by_risk
    render json: {
      message: "Route reordered by risk priority",
      route: serialize_route(route.reload, include_waypoints: true)
    }
  end

  def suggestions
    route = Route.find(params[:id])
    suggestions = RouteOptimizer.suggest_reroute(route)
    render json: {
      route_id: route.id,
      route_name: route.name,
      suggestions: suggestions
    }
  end

  def risk_assessment
    route = Route.find(params[:id])
    assessment = RouteRiskScorer.suggest_action(route)
    render json: assessment
  end

  def forecast
    route = Route.find(params[:id])
    forecast = PredictiveRiskEngine.forecast(route)
    render json: forecast
  end

  def early_warnings
    routes = Route.where(status: 'in_progress').includes(:truck, :waypoints)
    warnings = PredictiveRiskEngine.early_warnings(routes)

    render json: {
      generated_at: Time.current,
      threshold: PredictiveRiskEngine::EARLY_WARNING_THRESHOLD,
      warnings_count: warnings.count,
      warnings: warnings
    }
  end

  def recommend
    candidates = Route.where(status: 'planned').includes(:truck, :waypoints)
    constraints = optimization_constraints

    result = DynamicRouteOptimizer.recommend(candidates, constraints)

    render json: {
      optimization_mode: result[:optimization_mode],
      constraints: result[:constraints_applied],
      recommended: result[:recommended] ? serialize_recommendation(result[:recommended]) : nil,
      alternatives: result[:alternatives].map { |r| serialize_recommendation(r) },
      ineligible: result[:ineligible].map { |r| serialize_recommendation(r) }
    }
  end

  def compare
    route_ids = params[:route_ids] || []
    routes = Route.where(id: route_ids).includes(:truck, :waypoints)
    constraints = optimization_constraints

    comparisons = routes.map do |route|
      scores = DynamicRouteOptimizer.score_route(route, constraints)
      {
        route: serialize_route(route),
        scores: scores,
        tradeoffs: compute_tradeoffs(route, constraints)
      }
    end

    render json: {
      constraints: constraints,
      comparisons: comparisons.sort_by { |c| -c[:scores][:overall] }
    }
  end

  private

  def route_params
    params.require(:route).permit(
      :name, :origin, :destination, :truck_id,
      :max_transit_hours, :preferred_carrier, :allowed_detours,
      :temperature_sensitivity, :priority, :cost_estimate,
      :lane_risk_factor, :time_window_start, :time_window_end
    )
  end

  def optimization_constraints
    {
      max_risk: params[:max_risk]&.to_i,
      max_hours: params[:max_hours]&.to_i,
      max_cost: params[:max_cost]&.to_f,
      prefer_carrier: params[:prefer_carrier],
      time_window_start: params[:time_window_start].present? ? Time.parse(params[:time_window_start]) : nil,
      time_window_end: params[:time_window_end].present? ? Time.parse(params[:time_window_end]) : nil,
      optimize_for: params[:optimize_for] || 'balanced'
    }
  end

  def serialize_recommendation(rec)
    {
      route: serialize_route(rec[:route]),
      scores: rec[:scores],
      eligible: rec[:eligible],
      tradeoffs: rec[:tradeoffs]
    }
  end

  def compute_tradeoffs(route, constraints)
    risk = route.risk_score rescue 0
    tradeoffs = []

    if risk > 60
      tradeoffs << { factor: 'risk', message: "Elevated risk score: #{risk}" }
    end

    if constraints[:max_hours] && route.estimated_duration
      hours = route.estimated_duration / 60.0
      if hours > constraints[:max_hours]
        tradeoffs << { factor: 'time', message: "Exceeds time limit by #{(hours - constraints[:max_hours]).round(1)}h" }
      end
    end

    tradeoffs
  end

  def create_waypoints(route)
    return unless params[:site_ids].present?

    params[:site_ids].each_with_index do |site_id, index|
      next if site_id.blank?
      route.waypoints.create!(site_id: site_id, position: index + 1, status: 'pending')
    end
  end

  def serialize_route(route, include_waypoints: false)
    risk = route.risk_assessment rescue { score: 0, level: "unknown" }

    data = {
      id: route.id,
      name: route.name,
      origin: route.origin,
      destination: route.destination,
      status: route.status,
      truck_id: route.truck_id,
      truck_name: route.truck&.name,
      total_stops: route.total_stops,
      completed_stops: route.completed_stops,
      progress_percentage: route.progress_percentage,
      distance: route.distance,
      estimated_duration: route.estimated_duration,
      risk_score: risk[:score],
      risk_level: risk[:level],
      max_transit_hours: route.max_transit_hours,
      temperature_sensitivity: route.temperature_sensitivity,
      priority: route.priority,
      cost_estimate: route.cost_estimate,
      time_window_start: route.time_window_start,
      time_window_end: route.time_window_end,
      started_at: route.started_at,
      completed_at: route.completed_at,
      created_at: route.created_at,
      updated_at: route.updated_at
    }

    if include_waypoints
      data[:waypoints] = route.waypoints.map do |wp|
        {
          id: wp.id,
          position: wp.position,
          site_id: wp.site_id,
          site_name: wp.site.name,
          region_name: wp.site.region.name,
          status: wp.status,
          risk_score: wp.site_risk_level,
          arrival_time: wp.arrival_time,
          departure_time: wp.departure_time
        }
      end
    end

    data
  end
end
