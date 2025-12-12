class RoutesController < ApplicationController
  def index
    @routes = Route.includes(:truck, :waypoints).order(created_at: :desc)
  end

  def show
    @route = Route.includes(waypoints: :site).find(params[:id])
    @suggestions = RouteOptimizer.suggest_reroute(@route)
  end

  def new
    @route = Route.new
    @trucks = Truck.all
    @sites = Site.includes(:region).all
  end

  def create
    @route = Route.new(route_params)
    @route.status = 'draft'

    if @route.save
      create_waypoints
      redirect_to @route, notice: "Route created."
    else
      @trucks = Truck.all
      @sites = Site.includes(:region).all
      render :new
    end
  end

  def edit
    @route = Route.includes(waypoints: :site).find(params[:id])
    @trucks = Truck.all
    @sites = Site.includes(:region).all
  end

  def update
    @route = Route.find(params[:id])
    if @route.update(route_params)
      redirect_to @route, notice: "Route updated."
    else
      @trucks = Truck.all
      @sites = Site.includes(:region).all
      render :edit
    end
  end

  def destroy
    @route = Route.find(params[:id])
    @route.destroy
    redirect_to routes_path, notice: "Route deleted."
  end

  def optimize
    @route = Route.find(params[:id])
    RouteOptimizer.optimize(@route)
    redirect_to @route, notice: "Route optimized for shortest distance."
  end

  def reorder_by_risk
    @route = Route.find(params[:id])
    RouteOptimizer.new(@route).reorder_by_risk
    redirect_to @route, notice: "Route reordered by risk priority."
  end

  def start
    @route = Route.find(params[:id])
    if @route.can_start?
      @route.update!(status: 'in_progress')
      redirect_to @route, notice: "Route started."
    else
      redirect_to @route, alert: "Cannot start route. Ensure a truck is assigned."
    end
  end

  def complete
    @route = Route.find(params[:id])
    @route.update!(status: 'completed')
    redirect_to @route, notice: "Route completed."
  end

  def add_waypoint
    @route = Route.find(params[:id])
    site = Site.find(params[:site_id])
    position = @route.waypoints.maximum(:position).to_i + 1

    @route.waypoints.create!(site: site, position: position, status: 'pending')
    redirect_to @route, notice: "#{site.name} added to route."
  end

  def remove_waypoint
    @route = Route.find(params[:id])
    waypoint = @route.waypoints.find(params[:waypoint_id])
    waypoint.destroy

    # Reorder remaining waypoints
    @route.waypoints.order(:position).each_with_index do |wp, index|
      wp.update!(position: index + 1)
    end

    redirect_to @route, notice: "Waypoint removed."
  end

  def mark_waypoint_arrived
    @route = Route.find(params[:id])
    waypoint = @route.waypoints.find(params[:waypoint_id])
    waypoint.mark_arrived!
    redirect_to @route, notice: "Marked arrived at #{waypoint.site.name}."
  end

  def mark_waypoint_completed
    @route = Route.find(params[:id])
    waypoint = @route.waypoints.find(params[:waypoint_id])
    waypoint.mark_completed!
    redirect_to @route, notice: "Completed stop at #{waypoint.site.name}."
  end

  private

  def route_params
    params.require(:route).permit(:name, :origin, :destination, :truck_id, :status)
  end

  def create_waypoints
    return unless params[:site_ids].present?

    params[:site_ids].each_with_index do |site_id, index|
      next if site_id.blank?
      @route.waypoints.create!(site_id: site_id, position: index + 1, status: 'pending')
    end
  end
end
