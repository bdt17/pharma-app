class AnalyticsService
  def initialize(filters = {})
    @region_id = filters[:region_id]
    @site_id = filters[:site_id]
    @start_date = filters[:start_date] || 30.days.ago
    @end_date = filters[:end_date] || Time.current
  end

  def summary
    {
      total_trucks: trucks_scope.count,
      total_sites: sites_scope.count,
      total_regions: regions_scope.count,
      total_monitorings: monitorings_scope.count,
      total_excursions: excursions_count,
      excursion_rate: excursion_rate,
      high_risk_trucks: high_risk_trucks_count,
      active_routes: Route.active.count,
      period: { start_date: @start_date.to_date, end_date: @end_date.to_date }
    }
  end

  def by_region
    regions_scope.map do |region|
      region_monitorings = monitorings_for_region(region)
      excursions = count_excursions(region_monitorings)
      {
        region_id: region.id,
        region_name: region.name,
        sites_count: region.sites.count,
        trucks_count: region.trucks.count,
        monitorings_count: region_monitorings.count,
        excursions_count: excursions,
        excursion_rate: region_monitorings.count > 0 ? (excursions.to_f / region_monitorings.count * 100).round(2) : 0,
        high_risk_trucks: region.trucks.where(risk_level: ['high', 'critical']).count
      }
    end.sort_by { |r| -r[:excursions_count] }
  end

  def by_site
    sites_scope.includes(:region, :trucks).map do |site|
      site_monitorings = monitorings_for_site(site)
      excursions = count_excursions(site_monitorings)
      {
        site_id: site.id,
        site_name: site.name,
        region_id: site.region_id,
        region_name: site.region.name,
        trucks_count: site.trucks.count,
        monitorings_count: site_monitorings.count,
        excursions_count: excursions,
        excursion_rate: site_monitorings.count > 0 ? (excursions.to_f / site_monitorings.count * 100).round(2) : 0,
        high_risk_trucks: site.trucks.where(risk_level: ['high', 'critical']).count
      }
    end.sort_by { |s| -s[:excursions_count] }
  end

  def by_route
    routes_scope.includes(:truck, waypoints: :site).map do |route|
      route_site_ids = route.waypoints.pluck(:site_id)
      route_truck_ids = Truck.where(site_id: route_site_ids).pluck(:id)
      route_monitorings = Monitoring.where(truck_id: route_truck_ids)
                                    .where(recorded_at: @start_date..@end_date)
      excursions = count_excursions(route_monitorings)
      {
        route_id: route.id,
        route_name: route.name,
        status: route.status,
        stops_count: route.total_stops,
        monitorings_count: route_monitorings.count,
        excursions_count: excursions,
        excursion_rate: route_monitorings.count > 0 ? (excursions.to_f / route_monitorings.count * 100).round(2) : 0
      }
    end.sort_by { |r| -r[:excursions_count] }
  end

  def excursions_over_time(interval = :day)
    excursion_data = {}
    
    monitorings_scope.includes(truck: :site).find_each do |monitoring|
      next unless monitoring.truck&.out_of_range?(monitoring.temperature)
      
      key = case interval
            when :day
              monitoring.recorded_at.to_date
            when :week
              monitoring.recorded_at.beginning_of_week.to_date
            when :month
              monitoring.recorded_at.beginning_of_month.to_date
            end
      
      excursion_data[key] ||= 0
      excursion_data[key] += 1
    end

    excursion_data.sort.to_h
  end

  def excursions_by_region_over_time(interval = :day)
    result = {}
    
    regions_scope.each do |region|
      result[region.name] = {}
    end

    monitorings_scope.includes(truck: { site: :region }).find_each do |monitoring|
      next unless monitoring.truck&.out_of_range?(monitoring.temperature)
      next unless monitoring.truck&.site&.region
      
      region_name = monitoring.truck.site.region.name
      key = case interval
            when :day
              monitoring.recorded_at.to_date
            when :week
              monitoring.recorded_at.beginning_of_week.to_date
            when :month
              monitoring.recorded_at.beginning_of_month.to_date
            end
      
      result[region_name] ||= {}
      result[region_name][key] ||= 0
      result[region_name][key] += 1
    end

    result.transform_values { |dates| dates.sort.to_h }
  end

  def top_excursion_sites(limit = 10)
    by_site.first(limit)
  end

  def top_excursion_regions(limit = 10)
    by_region.first(limit)
  end

  private

  def trucks_scope
    scope = Truck.all
    scope = scope.joins(:site).where(sites: { region_id: @region_id }) if @region_id.present?
    scope = scope.where(site_id: @site_id) if @site_id.present?
    scope
  end

  def sites_scope
    scope = Site.all
    scope = scope.where(region_id: @region_id) if @region_id.present?
    scope = scope.where(id: @site_id) if @site_id.present?
    scope
  end

  def regions_scope
    scope = Region.all
    scope = scope.where(id: @region_id) if @region_id.present?
    scope
  end

  def routes_scope
    Route.all
  end

  def monitorings_scope
    scope = Monitoring.where(recorded_at: @start_date..@end_date)
    if @site_id.present?
      truck_ids = Truck.where(site_id: @site_id).pluck(:id)
      scope = scope.where(truck_id: truck_ids)
    elsif @region_id.present?
      site_ids = Site.where(region_id: @region_id).pluck(:id)
      truck_ids = Truck.where(site_id: site_ids).pluck(:id)
      scope = scope.where(truck_id: truck_ids)
    end
    scope
  end

  def monitorings_for_region(region)
    truck_ids = region.trucks.pluck(:id)
    Monitoring.where(truck_id: truck_ids, recorded_at: @start_date..@end_date)
  end

  def monitorings_for_site(site)
    truck_ids = site.trucks.pluck(:id)
    Monitoring.where(truck_id: truck_ids, recorded_at: @start_date..@end_date)
  end

  def excursions_count
    count_excursions(monitorings_scope)
  end

  def count_excursions(monitorings)
    count = 0
    monitorings.includes(:truck).find_each do |monitoring|
      count += 1 if monitoring.truck&.out_of_range?(monitoring.temperature)
    end
    count
  end

  def excursion_rate
    total = monitorings_scope.count
    return 0 if total.zero?
    (excursions_count.to_f / total * 100).round(2)
  end

  def high_risk_trucks_count
    trucks_scope.where(risk_level: ['high', 'critical']).count
  end
end
