class RouteOptimizer
  # Simulated coordinates for sites (in real app, would use geocoding)
  # Format: { site_id => [lat, lng] }

  def self.optimize(route)
    new(route).optimize
  end

  def self.suggest_reroute(route)
    new(route).suggest_reroute
  end

  def initialize(route)
    @route = route
  end

  def optimize
    sites = @route.waypoints.includes(:site).map(&:site).compact
    return @route if sites.size <= 2

    # Simple nearest-neighbor optimization
    optimized_order = nearest_neighbor_sort(sites)

    # Update waypoint positions
    ActiveRecord::Base.transaction do
      optimized_order.each_with_index do |site, index|
        waypoint = @route.waypoints.find_by(site: site)
        waypoint&.update!(position: index + 1)
      end

      update_route_estimates
    end

    @route.reload
  end

  def suggest_reroute
    suggestions = []

    @route.waypoints.pending.includes(:site).each do |waypoint|
      risk_score = waypoint.site_risk_level

      if risk_score > 70
        suggestions << {
          waypoint_id: waypoint.id,
          site_name: waypoint.site.name,
          risk_score: risk_score,
          recommendation: "HIGH PRIORITY - Consider visiting #{waypoint.site.name} immediately due to high risk score",
          action: :prioritize
        }
      elsif risk_score > 50
        suggestions << {
          waypoint_id: waypoint.id,
          site_name: waypoint.site.name,
          risk_score: risk_score,
          recommendation: "MEDIUM PRIORITY - #{waypoint.site.name} has elevated risk",
          action: :monitor
        }
      end
    end

    # Sort by risk score descending
    suggestions.sort_by { |s| -s[:risk_score] }
  end

  def reorder_by_risk
    pending_waypoints = @route.waypoints.pending.includes(:site)

    # Sort by risk score (highest first), then by original position
    sorted = pending_waypoints.sort_by do |wp|
      [-wp.site_risk_level, wp.position]
    end

    ActiveRecord::Base.transaction do
      completed_count = @route.waypoints.completed.count

      sorted.each_with_index do |waypoint, index|
        waypoint.update!(position: completed_count + index + 1)
      end

      update_route_estimates
    end

    @route.reload
  end

  def calculate_eta(waypoint)
    return nil unless @route.in_progress?

    completed = @route.waypoints.completed.count
    remaining = waypoint.position - completed

    # Estimate 30 minutes per stop + 45 minutes travel between stops
    minutes = remaining * 75
    Time.current + minutes.minutes
  end

  private

  def nearest_neighbor_sort(sites)
    return sites if sites.empty?

    remaining = sites.dup
    sorted = [remaining.shift] # Start with first site

    while remaining.any?
      current = sorted.last
      nearest = remaining.min_by { |site| distance_between(current, site) }
      sorted << nearest
      remaining.delete(nearest)
    end

    sorted
  end

  def distance_between(site1, site2)
    # Simulated distance calculation
    # In production, use actual geocoding/mapping API
    coords1 = site_coordinates(site1)
    coords2 = site_coordinates(site2)

    haversine_distance(coords1, coords2)
  end

  def site_coordinates(site)
    # Generate deterministic pseudo-coordinates based on site id
    # In production, store actual lat/lng on sites
    lat = 30.0 + (site.id % 20)
    lng = -90.0 + (site.id % 30)
    [lat, lng]
  end

  def haversine_distance(coords1, coords2)
    lat1, lng1 = coords1
    lat2, lng2 = coords2

    rad_per_deg = Math::PI / 180
    earth_radius_km = 6371

    dlat = (lat2 - lat1) * rad_per_deg
    dlng = (lng2 - lng1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlng / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius_km * c
  end

  def update_route_estimates
    total_distance = 0
    sites = @route.waypoints.order(:position).includes(:site).map(&:site).compact

    sites.each_cons(2) do |site1, site2|
      total_distance += distance_between(site1, site2)
    end

    # Estimate: 60 km/h average speed + 30 min per stop
    travel_time_hours = total_distance / 60.0
    stop_time_hours = sites.count * 0.5
    total_hours = travel_time_hours + stop_time_hours

    @route.update!(
      distance: total_distance.round(2),
      estimated_duration: (total_hours * 60).round # in minutes
    )
  end
end
