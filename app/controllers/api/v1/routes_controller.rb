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

  private

  def route_params
    params.require(:route).permit(:name, :origin, :destination, :truck_id)
  end

  def create_waypoints(route)
    return unless params[:site_ids].present?

    params[:site_ids].each_with_index do |site_id, index|
      next if site_id.blank?
      route.waypoints.create!(site_id: site_id, position: index + 1, status: 'pending')
    end
  end

  def serialize_route(route, include_waypoints: false)
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
